'use strict';

const shell = document.querySelector('.shell');
const buttons = Array.from(document.querySelectorAll('[data-set-state]'));

for (const button of buttons) {
  button.addEventListener('click', () => {
    const state = button.getAttribute('data-set-state');
    shell.setAttribute('data-state', state);
    for (const item of buttons) {
      item.setAttribute('aria-pressed', String(item === button));
    }
  });
}
