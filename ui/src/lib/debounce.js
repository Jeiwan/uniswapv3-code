export default (fn, timeout = 300) => {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => { fn.apply(this, args); }, timeout)
  };
}