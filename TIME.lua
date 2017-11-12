local TIME = {}
TIME.minute = 60
TIME.hour   = TIME.minute*60
TIME.day    = TIME.hour*24
TIME.week   = TIME.day*7
TIME.year   = TIME.day*365.25
TIME.days_in_months = {31,28,31,30,31,30,31,31,30,31,30,31}

return TIME
