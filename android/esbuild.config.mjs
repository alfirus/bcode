// Build: bundle src/main.ts -> dist/main.js, browser-only, no Node deps.
import * as esbuild from "esbuild";
import { execFile } from "node:child_process";
import fs from "node:fs/promises";

function packZip() {
  return new Promise((resolve, reject) => {
    execFile(process.execPath, ["./pack-zip.js"], (err, stdout) => {
      if (err) return reject(err);
      console.log(stdout.trim());
      resolve();
    });
  });
}

const cssText = {
  name: "css-text",
  setup(build) {
    build.onLoad({ filter: /\.css$/ }, async ({ path }) => {
      const source = await fs.readFile(path, "utf8");
      const { code } = await esbuild.transform(source, { loader: "css", minify: true });
      return { contents: `export default ${JSON.stringify(code)}`, loader: "js" };
    });
  },
};

const forbidNode = {
  name: "forbid-node",
  setup(build) {
    // bcode runs inside an Acode WebView: DOM + fetch only, like acode-ai-agent.
    build.onResolve({ filter: /^node:/ }, (args) => ({
      errors: [{ text: `Node runtime dependency is forbidden in the Acode client: ${args.path}` }],
    }));
  },
};

const buildConfig = {
  entryPoints: { main: "src/main.ts" },
  bundle: true,
  minify: true,
  platform: "browser",
  target: ["chrome90"],
  format: "iife",
  logLevel: "info",
  outdir: "dist",
  loader: { ".css": "text" },
  plugins: [forbidNode, cssText],
};

const result = await esbuild.build(buildConfig);
const externalImports = Object.values(result.metafile?.outputs ?? {}).flatMap((entry) =>
  entry.imports.filter((item) => item.external),
);
if (externalImports.length) {
  throw new Error(
    `Acode bundle has external runtime imports: ${externalImports.map((e) => e.path).join(", ")}`,
  );
}
await packZip();
console.log("bcode Acode client build complete.");
