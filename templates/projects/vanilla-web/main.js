let score = 0;
const output = document.getElementById('score');
function render() { output.textContent = `Điểm: ${score}`; }
document.getElementById('add').addEventListener('click', () => { score += 1; render(); });
document.getElementById('reset').addEventListener('click', () => { score = 0; render(); });
