const tests = {
  0: {
    label: "test 0",
    load: "assets/vgashot_test0_load.jpg",
    encrypt: "assets/vgashot_test0_encrypt.jpg",
    decrypt: "assets/vgashot_test0_decrypt.jpg",
    dashboard: "assets/screenshot_test0.png"
  },
  1: {
    label: "test 1",
    load: "assets/vgashot_test1_load.jpg",
    encrypt: "assets/vgashot_test1_encrypt.jpg",
    decrypt: "assets/vgashot_test1_decrypt.jpg",
    dashboard: "assets/screenshot_test1.png"
  },
  2: {
    label: "test 2",
    load: "assets/vgashot_test2_load.jpg",
    encrypt: "assets/vgashot_test2_encrypt.jpg",
    decrypt: "assets/vgashot_test2_decrypt.jpg",
    dashboard: "assets/screenshot_test2.png"
  }
};

const buttons = document.querySelectorAll("[data-test]");
const loadImg = document.querySelector("#img-load");
const encryptImg = document.querySelector("#img-encrypt");
const decryptImg = document.querySelector("#img-decrypt");
const dashboardImg = document.querySelector("#img-dashboard");

function selectTest(id) {
  const item = tests[id];
  if (!item) return;

  loadImg.src = item.load;
  loadImg.alt = `VGA output after loading ${item.label} image`;
  encryptImg.src = item.encrypt;
  encryptImg.alt = `VGA output after encrypting ${item.label} image`;
  decryptImg.src = item.decrypt;
  decryptImg.alt = `VGA output after decrypting ${item.label} image`;
  dashboardImg.src = item.dashboard;
  dashboardImg.alt = `Dashboard screenshot for ${item.label}`;

  buttons.forEach((button) => {
    const active = button.dataset.test === String(id);
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", active ? "true" : "false");
  });
}

buttons.forEach((button) => {
  button.addEventListener("click", () => selectTest(button.dataset.test));
});
