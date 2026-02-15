// code-copy.js
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('pre').forEach(pre => {
    // 避免重复添加
    if (pre.querySelector('.code-copy')) return;
    
    const btn = document.createElement('button');
    btn.className = 'code-copy';
    btn.textContent = '复制';
    btn.setAttribute('aria-label', '复制代码');
    
    // 添加到代码块中
    pre.style.position = 'relative'; // 确保定位生效
    pre.appendChild(btn);
    
    btn.addEventListener('click', async (e) => {
      e.stopPropagation(); // 防止事件冒泡
      const codeElem = pre.querySelector('code');
      if (!codeElem) return;
      
      const text = codeElem.innerText || codeElem.textContent;
      
      try {
        await navigator.clipboard.writeText(text);
        btn.textContent = '已复制';
        btn.classList.add('copied');
        
        setTimeout(() => {
          btn.textContent = '复制';
          btn.classList.remove('copied');
        }, 1500);
      } catch (err) {
        btn.textContent = '复制失败';
        setTimeout(() => btn.textContent = '复制', 1500);
      }
    });
  });
});