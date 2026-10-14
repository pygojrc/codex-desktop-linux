const copyButton = document.querySelector('.copy');

copyButton?.addEventListener('click', async () => {
  const command = 'curl -fsSL https://raw.githubusercontent.com/pygojrc/codex-desktop-linux/main/install.sh | sh';
  try {
    await navigator.clipboard.writeText(command);
    copyButton.textContent = '已复制';
    window.setTimeout(() => { copyButton.textContent = '复制'; }, 1800);
  } catch {
    copyButton.textContent = '请手动复制';
    window.setTimeout(() => { copyButton.textContent = '复制'; }, 2200);
  }
});
