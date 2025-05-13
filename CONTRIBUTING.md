
# Contributing to Eppascan

Thanks for your interest in contributing to **Eppascan**! Whether you're here to report bugs, suggest features, or submit code – you're welcome.

---

## 🛠 What You Can Contribute

- Fix bugs or improve existing scripts
- Add support for more Epson scanner models
- Enhance error handling or logging
- Improve documentation (README, usage examples, etc.)
- Translate docs or UI elements (future plan)

---

## 📋 How to Contribute

1. **Fork the repo**
2. **Create a new branch**  
   Example: `fix-logging` or `feature-new-scanner`
3. **Make your changes**
4. **Test locally**  
   Ensure the script still works with ES-500WII and doesn't break existing functionality.
5. **Commit with a clear message**
6. **Open a Pull Request (PR)**  
   Include a short summary of what you changed and why.

---

## ✅ Guidelines

- Keep scripts compatible with Debian-based systems
- Prefer simplicity and readability over clever tricks
- Use `bash` best practices (POSIX-compliant where possible)
- Test with `shellcheck` before committing:
  ```bash
  shellcheck eppascan.sh
  ```

---

## 🐞 Reporting Bugs

Open a [GitHub Issue](https://github.com/michael-hessi/Eppascan/issues) and include:

- Your OS and scanner model
- Error messages or logs
- Steps to reproduce

---

## 📜 License

By contributing, you agree that your code will be licensed under the [GNU GPL v3](LICENSE).

Happy scanning and hacking! 🤖
