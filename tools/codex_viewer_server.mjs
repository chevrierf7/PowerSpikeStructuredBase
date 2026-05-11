import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";

const root = "C:\\Users\\aho7\\Documents\\Codex\\PowerSpikeStructuredBase";
const port = 8765;
const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml"
};

function resolveRequest(url) {
  const parsed = new URL(url, `http://localhost:${port}`);
  const requested = decodeURIComponent(parsed.pathname).replace(/^\/+/, "");
  const target = path.resolve(root, requested || "tools/codex_capture_viewer.html");
  if (!target.startsWith(path.resolve(root))) {
    return null;
  }
  return target;
}

const server = http.createServer(async (req, res) => {
  const target = resolveRequest(req.url ?? "/");
  if (target === null) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }
  try {
    const data = await fs.readFile(target);
    res.writeHead(200, {
      "content-type": mimeTypes[path.extname(target).toLowerCase()] ?? "application/octet-stream",
      "cache-control": "no-store"
    });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end("Not found");
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Codex viewer listening on http://127.0.0.1:${port}/tools/codex_capture_viewer.html`);
});

setInterval(() => {}, 60_000);
