// today + DAYS as MM/DD/YYYY, the Material date picker's text-input format.
var d = new Date(Date.now() + Number(DAYS) * 86400000);
var two = function (n) { return ('0' + n).slice(-2); };
output.pickedDate = two(d.getMonth() + 1) + '/' + two(d.getDate()) + '/' + d.getFullYear();
