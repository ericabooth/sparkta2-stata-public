window.addEventListener('message', function(e){
  if(!e.data||e.data.type!=='sparkta2-resize') return;
  var ifrs=document.querySelectorAll('iframe');
  for(var i=0;i<ifrs.length;i++){
    if(ifrs[i].contentWindow===e.source){
      if(ifrs[i].hasAttribute('data-skip-resize')) break;
      ifrs[i].style.height=(e.data.height+12)+'px';
      ifrs[i].setAttribute('scrolling','no');
      break;
    }
  }
});
