'use strict';

const shell = document.querySelector('.shell');
const buttons = Array.from(document.querySelectorAll('[data-helm-set-state]'));

for (const button of buttons) {
  button.addEventListener('click', () => {
    const state = button.getAttribute('data-helm-set-state');
    shell.setAttribute('data-helm-state', state);
    for (const item of buttons) {
      item.setAttribute('aria-pressed', String(item === button));
    }
  });
}
