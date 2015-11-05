uart.setup(0,115200,8,0,1,1)
wifi.setmode(1)
wifi.sta.connect('homeus','gehtwieder')
dofile('restful-server.lc')

