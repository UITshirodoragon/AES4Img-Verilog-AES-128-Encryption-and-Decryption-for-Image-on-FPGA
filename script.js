(() => {
  const tests = {
    0: {
      title: "Test 0",
      label: "test 0",
      load: "assets/vgashot_test0_load.jpg",
      encrypt: "assets/vgashot_test0_encrypt.jpg",
      decrypt: "assets/vgashot_test0_decrypt.jpg",
      dashboard: "assets/screenshot_test0.png"
    },
    1: {
      title: "Test 1",
      label: "test 1",
      load: "assets/vgashot_test1_load.jpg",
      encrypt: "assets/vgashot_test1_encrypt.jpg",
      decrypt: "assets/vgashot_test1_decrypt.jpg",
      dashboard: "assets/screenshot_test1.png"
    },
    2: {
      title: "Test 2",
      label: "test 2",
      load: "assets/vgashot_test2_load.jpg",
      encrypt: "assets/vgashot_test2_encrypt.jpg",
      decrypt: "assets/vgashot_test2_decrypt.jpg",
      dashboard: "assets/screenshot_test2.png"
    }
  };

  function preloadGalleryImages() {
    Object.values(tests).forEach((item) => {
      [item.load, item.encrypt, item.decrypt, item.dashboard].forEach((src) => {
        const image = new Image();
        image.src = src;
      });
    });
  }

  function bootGallery() {
    const buttons = document.querySelectorAll("[data-test]");
    const galleryGrid = document.querySelector("#gallery-grid");
    const dashboardShot = document.querySelector("#dashboard-shot");
    const status = document.querySelector("#gallery-status");

    const loadImg = document.querySelector("#img-load");
    const encryptImg = document.querySelector("#img-encrypt");
    const decryptImg = document.querySelector("#img-decrypt");
    const dashboardImg = document.querySelector("#img-dashboard");

    const captionLoad = document.querySelector("#caption-load");
    const captionEncrypt = document.querySelector("#caption-encrypt");
    const captionDecrypt = document.querySelector("#caption-decrypt");
    const captionDashboard = document.querySelector("#caption-dashboard");

    if (!buttons.length || !galleryGrid || !dashboardShot || !status) return;

    function restartAnimation() {
      galleryGrid.classList.remove("is-switching");
      dashboardShot.classList.remove("is-switching");
      void galleryGrid.offsetWidth;
      galleryGrid.classList.add("is-switching");
      dashboardShot.classList.add("is-switching");
    }

    function selectTest(id) {
      const item = tests[id];
      if (!item) return;

      restartAnimation();
      status.textContent = `Showing ${item.title}`;

      loadImg.src = item.load;
      loadImg.alt = `VGA output after loading ${item.label} image`;
      encryptImg.src = item.encrypt;
      encryptImg.alt = `VGA output after encrypting ${item.label} image`;
      decryptImg.src = item.decrypt;
      decryptImg.alt = `VGA output after decrypting ${item.label} image`;
      dashboardImg.src = item.dashboard;
      dashboardImg.alt = `Dashboard screenshot for ${item.label}`;

      captionLoad.textContent = `${item.title.toUpperCase()} / LOAD`;
      captionEncrypt.textContent = `${item.title.toUpperCase()} / ENCRYPT`;
      captionDecrypt.textContent = `${item.title.toUpperCase()} / DECRYPT`;
      captionDashboard.textContent = `${item.title.toUpperCase()} / VGA dashboard and quadrant layout`;

      buttons.forEach((button) => {
        const active = button.dataset.test === String(id);
        button.classList.toggle("active", active);
        button.setAttribute("aria-selected", active ? "true" : "false");
      });
    }

    buttons.forEach((button) => {
      button.addEventListener("click", () => selectTest(button.dataset.test));
    });

    preloadGalleryImages();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootGallery);
  } else {
    bootGallery();
  }
})();
