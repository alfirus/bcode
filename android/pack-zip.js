// Pack dist/main.js + metadata into plugin.zip for sideloading into Acode.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import JSZip from "jszip";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const pluginJSON = path.join(__dirname, "plugin.json");
const distFolder = path.join(__dirname, "dist");
const json = JSON.parse(fs.readFileSync(pluginJSON, "utf8"));
const iconName = json.icon || "icon.png";

const zip = new JSZip();
zip.file("plugin.json", fs.readFileSync(pluginJSON));
zip.file(iconName, fs.readFileSync(path.join(__dirname, iconName)));
for (const name of ["LICENSE", json.readme, json.changelogs]) {
  if (name && fs.existsSync(path.join(__dirname, name))) {
    zip.file(path.basename(name), fs.readFileSync(path.join(__dirname, name)));
  }
}

for (const file of fs.readdirSync(distFolder)) {
  if (/LICENSE\.txt/.test(file)) continue;
  zip.file(file, fs.readFileSync(path.join(distFolder, file)));
}

zip
  .generateNodeStream({ type: "nodebuffer", streamFiles: true })
  .pipe(fs.createWriteStream(path.join(__dirname, "plugin.zip")))
  .on("finish", () => console.log("plugin.zip written."));
