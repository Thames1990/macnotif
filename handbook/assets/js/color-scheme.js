(() => {
  const button = document.getElementById("color-scheme-toggle");
  const key = "macnotif-handbook-color-scheme";

  function storageWarning(error) {
    if (!(error instanceof DOMException) ||
        !["SecurityError", "QuotaExceededError"].includes(error.name)) {
      throw error;
    }
    console.warn("MacNotif handbook: color preference cannot be saved in this browser.", error);
  }

  let saved;
  try {
    saved = localStorage.getItem(key);
  } catch (error) {
    storageWarning(error);
  }

  function apply(scheme) {
    jtd.setTheme(scheme);
    document.documentElement.style.colorScheme = scheme;
    button.setAttribute("aria-pressed", String(scheme === "dark"));
  }

  const systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  apply(saved === "dark" || saved === "light" ? saved : (systemDark ? "dark" : "light"));

  button.addEventListener("click", () => {
    const scheme = button.getAttribute("aria-pressed") === "true" ? "light" : "dark";
    apply(scheme);
    try {
      localStorage.setItem(key, scheme);
    } catch (error) {
      storageWarning(error);
    }
  });
})();
