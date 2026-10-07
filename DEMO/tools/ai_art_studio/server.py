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
    GET  /rt-store                → 运行时配对存储：列出全部记录（dict 保插入序 =
                                    完成顺序），供页面刷新后恢复生成图与提示词
    POST /rt-store                → 运行时配对存储：写入单条记录（同 uid 原位替换
                                    幂等）；总量超 512MiB 软上限拒收（200 +
                                    reason=full，页面提示但不影响生成）
    POST /rt-store-delete         → 运行时配对存储：按 uid 删单条（页面删图联动）
    POST /rt-store-clear          → 运行时配对存储：清空全部（页面「清空」联动）

运行时存储口径：纯内存、会话级——随 server.py 进程存活（刷新页面不丢，关闭
server.py 即全清）；排队/生成中/失败任务不写入，仅生成成功时保存；API Key
与鉴权配置一律不进存储（页面按字段白名单构造 + 服务端按白名单重建双防线）。

安全：仅监听 127.0.0.1（不对外）；目标 URL 必须 https:// 开头（防滥用）；
/proxy-get 额外限图片（URL 扩展名 png/jpg/jpeg/webp/gif/bmp 或上游
Content-Type 为 image/*，非图片一律 415 拒绝，防被当任意下载器滥用）；
/rt-* 端点轻量 Origin 防护（Origin 缺失 / null（file://）/ 127.0.0.1 /
localhost 放行，其余 403——防别的网页借本机端口读写缓存）；
请求日志剥离 query（防 Gemini key 泄露到控制台）。
"""

import json
import os
import sys
import threading
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

# ---------- 运行时配对存储（/rt-* 端点 · 纯内存 · 会话级） ----------
# uid → record；dict 保插入序 = 完成顺序；同 uid 重复 POST 原位替换（幂等，位置不变）。
# 关闭 server.py 即全清（不落盘）；容量软上限（方案常量表）：总量 512MiB / 单条 64MiB。
RT_STORE = {}
RT_BYTES = 0                      # 全部记录 img_b64 + url + prompt 的 UTF-8 字节数合计
RT_LOCK = threading.Lock()        # 检查容量 + 增删改 + 读取快照全部单一临界区
RT_MAX_TOTAL_BYTES = 536870912    # 512MiB：总量软上限，超出拒收新记录（200 + reason=full）
RT_MAX_RECORD_BYTES = 67108864    # 64MiB：单条上限，超出 413
RT_BODY_OVERHEAD = 1048576        # 请求体读取上限的额外开销余量（JSON 结构 / 字段名）
# record 字段白名单：服务端按白名单重建 dict，未知字段一律丢弃——
# 页面侧即使误传 apiKey / baseUrl / auth 等配置字段也不会被存储或回发（第二道防线）
RT_FIELDS = ("uid", "item_id", "item_name", "prompt", "provider", "model", "size_label",
             "time", "duration_ms", "ref_count", "url_source", "url", "mime", "img_b64")


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
        if path == "/rt-store":
            if not self._rt_origin_ok():
                return
            self._serve_rt_store_get()
            return
        self._serve_static(path)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/proxy":
            self._serve_proxy()
            return
        if path == "/rt-store":
            if not self._rt_origin_ok():
                return
            self._serve_rt_store_post()
            return
        if path == "/rt-store-delete":
            if not self._rt_origin_ok():
                return
            self._serve_rt_store_delete()
            return
        if path == "/rt-store-clear":
            if not self._rt_origin_ok():
                return
            self._serve_rt_store_clear()
            return
        self._send_json(404, {"error": "not found（本服务仅支持 GET 静态 / GET ping / GET proxy-get / GET rt-store / "
                                       "POST proxy / POST rt-store / POST rt-store-delete / POST rt-store-clear）"})

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

    # ---------- 运行时配对存储（/rt-* 端点 · 纯内存 · 随本进程存活） ----------
    def _rt_origin_ok(self):
        """轻量 Origin 防护（仅 /rt-* 端点）。

        Origin 头缺失（curl / 同源 fetch）或 null（file:// 页面）或
        http://127.0.0.1: / http://localhost: 开头（本机伺服页面）→ 放行；
        其余（别的网站借浏览器跨域读写本机缓存）→ 403 拒绝。
        """
        origin = self.headers.get("Origin")
        if not origin or origin == "null":
            return True
        low = origin.lower()
        if low.startswith("http://127.0.0.1:") or low.startswith("http://localhost:"):
            return True
        self._send_json(403, {"error": "forbidden（Origin 不在本机白名单：仅允许无 Origin / file:// / 127.0.0.1 / localhost）"})
        return False

    @staticmethod
    def _rt_record_size(record):
        """记录占用字节数：img_b64 + url + prompt 三段的 UTF-8 字节合计。"""
        n = 0
        for key in ("img_b64", "url", "prompt"):
            value = record.get(key) if isinstance(record, dict) else None
            if isinstance(value, str):
                n += len(value.encode("utf-8"))
        return n

    def _rt_read_body(self):
        """读 POST 请求体（Content-Length 模式同 _serve_proxy），读前校验长度上限。

        返回 (bytes, None) 或 (None, (状态码, 错误响应))。
        """
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length <= 0:
            return None, (400, {"error": "缺少请求体"})
        if length > RT_MAX_RECORD_BYTES + RT_BODY_OVERHEAD:
            return None, (413, {"error": "请求体过大（单条上限 64MiB + 1MiB 开销），收到 %d 字节" % length})
        return self.rfile.read(length), None

    def _serve_rt_store_get(self):
        """GET /rt-store：锁内浅拷贝快照后回发全部记录（dict 插入序 = 完成顺序）。"""
        with RT_LOCK:
            items = list(RT_STORE.values())
            count = len(RT_STORE)
            bytes_total = RT_BYTES
        self._send_json(200, {
            "ok": True,
            "count": count,
            "bytes_total": bytes_total,
            "max_bytes": RT_MAX_TOTAL_BYTES,
            "items": items,
        })

    def _serve_rt_store_post(self):
        """POST /rt-store：写入单条记录（字段白名单重建 + 容量软上限检查 + 幂等替换）。"""
        global RT_BYTES
        body, err = self._rt_read_body()
        if err is not None:
            self._send_json(err[0], err[1])
            return
        try:
            data = json.loads(body.decode("utf-8"))
            if not isinstance(data, dict):
                raise ValueError("not a json object")
        except Exception:
            self._send_json(400, {"error": "请求体不是合法 JSON 对象"})
            return
        # 服务端白名单重建：未知字段一律丢弃（防泄露第二道防线，见 RT_FIELDS 注释）
        record = {}
        for key in RT_FIELDS:
            if key in data:
                record[key] = data[key]
        uid = record.get("uid")
        if not isinstance(uid, str) or not uid:
            self._send_json(400, {"error": "缺少 uid 字段（string）"})
            return
        size = self._rt_record_size(record)
        if size > RT_MAX_RECORD_BYTES:
            self._send_json(413, {"error": "单条记录超出上限（%d > %d 字节）" % (size, RT_MAX_RECORD_BYTES)})
            return
        with RT_LOCK:
            old = RT_STORE.get(uid)
            candidate = RT_BYTES - (self._rt_record_size(old) if old else 0) + size
            if candidate > RT_MAX_TOTAL_BYTES:
                # 总量软上限：拒收不改状态（HTTP 200 + reason=full，页面据此提示）
                self._send_json(200, {"ok": False, "reason": "full",
                                      "bytes_total": RT_BYTES, "max_bytes": RT_MAX_TOTAL_BYTES})
                return
            RT_STORE[uid] = record  # 同 uid 原位替换（dict 语义：已存在的键保持原插入位置）
            RT_BYTES = candidate
            self._send_json(200, {"ok": True, "count": len(RT_STORE), "bytes_total": RT_BYTES})

    def _serve_rt_store_delete(self):
        """POST /rt-store-delete：{uid} 按键删单条（页面删图联动）。"""
        global RT_BYTES
        body, err = self._rt_read_body()
        if err is not None:
            self._send_json(err[0], err[1])
            return
        try:
            data = json.loads(body.decode("utf-8"))
        except Exception:
            self._send_json(400, {"error": "请求体不是合法 JSON"})
            return
        uid = data.get("uid") if isinstance(data, dict) else None
        if not isinstance(uid, str) or not uid:
            self._send_json(400, {"error": "缺少 uid 字段（string）"})
            return
        with RT_LOCK:
            old = RT_STORE.pop(uid, None)
            if old is not None:
                RT_BYTES -= self._rt_record_size(old)
            self._send_json(200, {"ok": True, "deleted": old is not None})

    def _serve_rt_store_clear(self):
        """POST /rt-store-clear：清空全部记录（页面「清空」按钮联动）。"""
        global RT_BYTES
        with RT_LOCK:
            cleared = len(RT_STORE)
            RT_STORE.clear()
            RT_BYTES = 0
            self._send_json(200, {"ok": True, "cleared": cleared})


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
    print("  运行时存: GET/POST http://127.0.0.1:%d/rt-store（生成图+提示词 · 内存级 · 刷新自动恢复 · 关服即清）" % port)
    print("            POST /rt-store-delete（按 uid 删）/ POST /rt-store-clear（清空）")
    print("  仅监听本机 127.0.0.1；关闭本窗口或 Ctrl+C 即停止（运行时缓存随进程一并清空）。")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止。")


if __name__ == "__main__":
    main()
