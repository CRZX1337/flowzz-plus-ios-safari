// flowzz+ Safari web extension — placeholder popup script.
//
// Safari exposes both the chrome.* and browser.* namespaces; the scaffold uses
// whichever one exists. Nothing here talks to a backend.
const api = typeof browser !== "undefined" ? browser : chrome;

const button = document.getElementById("ping");
const status = document.getElementById("status");

button.addEventListener("click", () => {
  const version = api.runtime.getManifest().version;
  status.textContent = `Extension ${version} is alive. Replace this popup with the flowzz+ UI.`;
  console.debug("[flowzz+] popup test message", { version });
});
