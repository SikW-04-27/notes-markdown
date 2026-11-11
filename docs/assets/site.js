const examples = {
  zh: {
    bold: { source: '**本周计划**', result: '本周计划', trigger: '闭合星号后自动转换' },
    title: { source: '# 本周计划', result: '本周计划', trigger: '在行首输入 #，再按空格' },
    checklist: { source: '[ ] 整理本周计划', result: '整理本周计划', trigger: '在行首输入 [ ]，再按空格' }
  },
  en: {
    bold: { source: '**Weekly plan**', result: 'Weekly plan', trigger: 'Converts after the closing stars' },
    title: { source: '# Weekly plan', result: 'Weekly plan', trigger: 'Type # at the start of a line, then Space' },
    checklist: { source: '[ ] Plan the week', result: 'Plan the week', trigger: 'Type [ ] at the start of a line, then Space' }
  }
};
const language = document.documentElement.lang.startsWith('zh') ? 'zh' : 'en';
const source = document.querySelector('[data-demo-source]');
const result = document.querySelector('[data-demo-result]');
const trigger = document.querySelector('[data-demo-trigger]');
const buttons = document.querySelectorAll('[data-example]');
for (const button of buttons) {
  button.addEventListener('click', () => {
    const style = button.dataset.example;
    const example = examples[language][style];
    source.textContent = example.source;
    result.textContent = example.result;
    result.className = `demo-result ${style}`;
    trigger.textContent = example.trigger;
    for (const item of buttons) {
      item.setAttribute('aria-pressed', String(item === button));
    }
  });
}
