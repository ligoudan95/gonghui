#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AI 生图工作台 · 本地静态 + API 转发二合一服务器（Python3 标准库，零依赖）。

为什么需要它：daseinai.xyz 等站点对浏览器 CORS 预检一律 403 且不返回跨域头，
网页内直接 fetch 该站必报 Failed to fetch（curl 不受影响）。本服务在本机
127.0.0.1 伺服工具静态页，并把页面发起的 API 请求原样转发到目标端点、响应
原样透传回浏览器——等效 curl 链路，绕开浏览器 CORS 限制。

用法：
    python server.py [端口]      # 默认 8765
    （或直接双击同目录「启动工作台.cmd」）

端点：
    GET  /                        → index.html（及同目录静态文件）
    GET  /ping                    → 200 纯文本 ok（页面探测代理可用性）
    GET  /proxy-get?url=<图片URL>  → 服务端 GET 下载目标图片并回传字节流（带 CORS
                                    头）——代理模式下页面用它下载跨域受限的 URL
                                    源生成图（grsai 等端点返回 data[0].url 形态）
    POST /proxy?url=<目标完整URL>  → 转发 POST：透传 Authorization / Content-Type /
                                    请求体；透传上游状态码与响应体（错误原文可
                                    在页面错误区看到）

安全：仅监听 127.0.0.1（不对外）；目标 URL 必须 https:// 开头（防滥用）；
/proxy-get 额外限图片（URL 扩展名 png/jpg/jpeg/webp/gif/bmp 或上游
Content-Type 为 image/*，非图片一律 415 拒绝，防被当任意下载器滥用）；
请求日志剥离 query（防 Gemini key 泄露到控制台）。
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PORT = 8765
UPSTREAM_TIMEOUT_SEC = 180  # 生图慢，上游超时放宽到 3 分钟

# CORS 三头：允许任何本地页面（file:// 打开或其他端口伺服）跨域调用本代理
CORS_HEADERS = [
    ("Access-Control-Allow-Origin", "*"),
    ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
    ("Access-Control-Allow-Headers", "Authorization, Content-Type"),
]

# 静态文件扩展名 → MIME（Windows 注册表 guess 不可靠，优先查本表）
STATIC_MIME = {
    ".html": "text/html; charset=utf-8",
    ".htm": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".md": "text/markdown; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
}

# /proxy-get 允许下载的图片扩展名（防滥用：非 https / 非图片一律拒绝）
PROXY_GET_IMG_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp"}


class StudioHandler(BaseHTTPRequestHandler):
    """静态伺服 + /ping 探测 + /proxy 转发。"""

    server_version = "AIArtStudioServer/1.0"
    protocol_version = "HTTP/1.1"  # keep-alive（所有响应都带 Content-Length）

    # ---------- 日志（剥离 query，防 Gemini key 泄露到控制台） ----------
    def log_request(self, code="-", size="-"):
        try:
            path_only = urllib.parse.urlparse(self.path).path
            sys.stderr.write("%s - - [%s] %s %s -> %s\n" % (
                self.address_string(), self.log_date_time_string(),
                self.command, path_only, code))
        except Exception:
            pass

    # ---------- 统一发送（全部响应带 CORS 三头 + Content-Length） ----------
    def _send(self, status, ctype, body):
        if isinstance(body, str):
            body = body.encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            for key, value in CORS_HEADERS:
                self.send_header(key, value)
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # 客户端提前断开（页面刷新 / 请求取消），不算错误

    def _send_json(self, status, obj):
        """JSON 错误响应（UTF-8，中文可读）。"""
        self._send(status, "application/json; charset=utf-8",
                   json.dumps(obj, ensure_ascii=False))

    # ---------- 路由 ----------
    def do_OPTIONS(self):
        # CORS 预检：带 Authorization 头的跨域 fetch（如 file:// 页面）会先发 OPTIONS
        self._send(200, "text/plain; charset=utf-8", "")

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/ping":
            self._send(200, "text/plain; charset=utf-8", "ok")
            return
        if path == "/proxy-get":
            self._serve_proxy_get()
            return
        self._serve_static(path)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path != "/proxy":
            self._send_json(404, {"error": "not found（本服务仅支持 GET 静态 / GET ping / GET proxy-get / POST proxy）"})
            return
        self._serve_proxy()

    # ---------- 静态文件（限本目录，防路径穿越） ----------
    def _serve_static(self, url_path):
        rel = urllib.parse.unquote(url_path).lstrip("/") or "index.html"
        full = os.path.realpath(os.path.join(BASE_DIR, rel))
        base_real = os.path.realpath(BASE_DIR)
        if full != base_real and not full.startswith(base_real + os.sep):
            self._send_json(403, {"error": "forbidden（路径越界）"})
            return
        if not os.path.isfile(full):
            self._send_json(404, {"error": "not found: " + url_path})
            return
        ext = os.path.splitext(full)[1].lower()
        ctype = STATIC_MIME.get(ext, "application/octet-stream")
        with open(full, "rb") as f:
            data = f.read()
        self._send(200, ctype, data)

    # ---------- API 转发 ----------
    def _serve_proxy(self):
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        target = (query.get("url") or [""])[0].strip()
        if not target:
            self._send_json(400, {"error": "缺少 url 参数（用法：POST /proxy?url=<目标完整URL>）"})
            return
        if not target.lower().startswith("https://"):
            self._send_json(400, {"error": "目标 URL 必须以 https:// 开头（防滥用），收到: " + target})
            return

        # 读请求体与待转发头（只透传 Authorization / Content-Type）
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        body = self.rfile.read(length) if length > 0 else None
        fwd_headers = {"User-Agent": self.server_version}  # 部分网关拒收 python-urllib 默认 UA
        if self.headers.get("Authorization"):
            fwd_headers["Authorization"] = self.headers.get("Authorization")
        if self.headers.get("Content-Type"):
            fwd_headers["Content-Type"] = self.headers.get("Content-Type")

        req = urllib.request.Request(target, data=body, headers=fwd_headers, method="POST")
        try:
            resp = urllib.request.urlopen(req, timeout=UPSTREAM_TIMEOUT_SEC)
        except urllib.error.HTTPError as e:
            # 上游 4xx/5xx：状态码 / Content-Type / 响应体原样透传（页面须看到原始报文）
            try:
                err_body = e.read()
            except Exception:
                err_body = b""
            ctype = (e.headers.get("Content-Type") if e.headers else None) or "application/octet-stream"
            self._send(e.code, ctype, err_body)
            return
        except Exception as e:
            self._send_json(502, {"error": "上游请求失败: %s: %s" % (type(e).__name__, e)})
            return

        try:
            data = resp.read()  # b64 图可达数 MB，整读后一次发（Content-Length 已知）
            ctype = resp.headers.get("Content-Type") or "application/octet-stream"
            self._send(resp.status, ctype, data)
        except Exception as e:
            self._send_json(502, {"error": "读取上游响应失败: %s: %s" % (type(e).__name__, e)})
        finally:
            try:
                resp.close()
            except Exception:
                pass

    # ---------- 图片下载代理（URL 源生成图的跨域下载出口） ----------
    def _serve_proxy_get(self):
        """GET /proxy-get?url=<https 图片地址>：服务端下载目标图片回传字节流。

        防滥用：目标必须 https://；且必须是图片——URL 扩展名在图片集合内
        或上游 Content-Type 为 image/*，二者皆非则 415 拒绝。响应带 CORS 头
        （_send 统一附加），供页面跨域 fetch。
        """
        query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        target = (query.get("url") or [""])[0].strip()
        if not target:
            self._send_json(400, {"error": "缺少 url 参数（用法：GET /proxy-get?url=<图片完整URL>）"})
            return
        if not target.lower().startswith("https://"):
            self._send_json(400, {"error": "目标 URL 必须以 https:// 开头（防滥用），收到: " + target})
            return

        req = urllib.request.Request(target, headers={"User-Agent": self.server_version}, method="GET")
        try:
            resp = urllib.request.urlopen(req, timeout=UPSTREAM_TIMEOUT_SEC)
        except urllib.error.HTTPError as e:
            try:
                err_body = e.read()
            except Exception:
                err_body = b""
            self._send_json(e.code, {"error": "上游 HTTP %s" % e.code,
                                     "upstream_body": err_body[:500].decode("utf-8", "replace")})
            return
        except Exception as e:
            self._send_json(502, {"error": "上游请求失败: %s: %s" % (type(e).__name__, e)})
            return

        try:
            data = resp.read()
            ctype_raw = resp.headers.get("Content-Type") or ""
            ctype = ctype_raw.split(";")[0].strip().lower()
            ext = os.path.splitext(urllib.parse.urlparse(target).path)[1].lower()
            is_image = ctype.startswith("image/") or ext in PROXY_GET_IMG_EXT
            if not is_image:
                self._send_json(415, {"error": "目标不是图片（Content-Type=%s，扩展名=%s），仅代理图片下载"
                                     % (ctype or "空", ext or "无")})
                return
            out_ctype = ctype if ctype.startswith("image/") else (STATIC_MIME.get(ext) or "application/octet-stream")
            self._send(200, out_ctype, data)
        except Exception as e:
            self._send_json(502, {"error": "读取上游响应失败: %s: %s" % (type(e).__name__, e)})
        finally:
            try:
                resp.close()
            except Exception:
                pass


def main():
    # Windows 控制台默认 GBK：reconfigure 防中文/特殊字符打印炸掉（不可编码字符替换显示）
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="replace")
        except Exception:
            pass

    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("用法: python server.py [端口]（默认 %d）" % DEFAULT_PORT)
            sys.exit(2)

    try:
        server = ThreadingHTTPServer(("127.0.0.1", port), StudioHandler)
    except OSError as e:
        print("无法监听 127.0.0.1:%d（%s）" % (port, e))
        print("常见原因：server.py 已在另一窗口运行——直接用浏览器打开 http://127.0.0.1:%d/ 即可。" % port)
        sys.exit(1)
    server.daemon_threads = True

    print("AI 生图工作台 · 本地服务已启动")
    print("  页面地址: http://127.0.0.1:%d/" % port)
    print("  代理探测: GET  http://127.0.0.1:%d/ping" % port)
    print("  API 转发: POST http://127.0.0.1:%d/proxy?url=<目标完整URL>" % port)
    print("  图片代理: GET  http://127.0.0.1:%d/proxy-get?url=<图片完整URL>" % port)
    print("  仅监听本机 127.0.0.1；关闭本窗口或 Ctrl+C 即停止。")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止。")


if __name__ == "__main__":
    main()
