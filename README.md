## AEM dumping via libjaylink

This is probably more useful.  You can do things like Simplicity Studio's
Energy profiler, by hooking this to, for instance, kst2...

```
./aem-dump -c -m1 | tee -a dump1.log;
kst2 # and then import the dump1.log and you can get live current/voltage monitoring...
```
![kst2-screenshot](kst-screengrab.png)

Or, you can just run it at the command line...

```
$ ./aem-dump -m100
Using J-link with serial: 000440182579
 > ts: 4957984, current_ma: 0.361671, voltage: 3.332263
 > ts: 4958034, current_ma: 0.161100, voltage: 3.335224
 > ts: 4958085, current_ma: 0.074937, voltage: 3.332802
 > ts: 4958135, current_ma: 0.239495, voltage: 3.331456
 > ts: 4958185, current_ma: 0.101246, voltage: 3.329302
 > ts: 4958236, current_ma: 0.094511, voltage: 3.332263
 > ts: 4958286, current_ma: 0.243982, voltage: 3.336031
 > ts: 4958337, current_ma: 0.070962, voltage: 3.333340
```

'ts' is the time in milliseconds since the jlink was powered on.

### Requirements
This works with the jlink on the "WSTK" BRD4001A. (EFR32 boards, jlink has ethernet, quite recent)
It does **not** work with the jlink on BRD2012A EFM32 Happy Gecko.  However, I've got some packet traces,
and have partially decoded protocol there.  It's not really a target for me at this point though
so this may go no further.

### Building
Needs *libjaylink* and a C compiler.
libjaylink-devel is available for fedora at least, if not, get it from [libjaylink](https://gitlab.zapb.de/libjaylink/libjaylink)

## wireshark usb decoder for jlink traffic

it's not _remotely_ finished, but the stub is there to plug in a statemachine....

### useful bits of decoder help...
```
x = "abcdefg...some-hex-string...." (right click from wireshark copy as hex stream)
>>> struct.unpack("<Ifff", binascii.unhexlify(x[32:64]))
(1079682453, 3.416356325149536, 3.4178173542022705, 3.420008897781372)

```

### ssv5-aem-polling-old-efm32hg.pcapng
This is a trace to try and make aem-dump work on an older EFM32HG board.
from SSv5, this is "the same" but clearly quite different internally.

This is just a blinking led, toggling between 3.4mA and 3.9mA, at 100ms in each state
frame 18168 (1024 byte chunk) appears to be a continous chunk of floats of current?
however, it's 256 readings, at what interval?! we _only_ see 3.4mA in it?
18166, just before, first line could be 1000, 256, 1462?  (10khz, 256 records in next sample?)
time is 9.291752, next 1k chunk comes at time 9.305747. 

frame 18312 at 9.367962 (delta 70ms) contains 256 floats of ~3.91, so this is definitely 
current measurements, yay.


from the top, we see...
emucom read 0x10002, 4096.
< 4bytes: 060400
< 32bytes: stuff, always eaeaaeae....... lots of zeros
< 64bytes: ? voltage readings perhaps? (at least offset 0x60 seems to be voltage as a float?)
< 1024b bytes: these are 256 le floats, with current in mA...
then it repeats...
but, if first reply is a 0000, then there' "nothing else?"
and we move to check the SWO channel?

there's also emucom ch 0x1000b in action?


Ok, so summary:
emucom 1000b is swo, it reads the channel, sees no data, moves on
emucom 10002 is aem, it reads the channel, gets four replies.
packet 4 has currents, just packed LE floats, packet 3 has... a voltage in it?
packet 3 also starts with 10000, which might be a sampling rate?
packet 1 and 2 are presumably metadata and timing information?

### ssv5-aem-polling-old-efm32hg-with-start.pcapng
As above, but recorded from before SSv5 turned on the energy profiler.
I _believe_ the only interesting packet is 93/625, where it does a write to emucom ch 0x10002
I believe this is turning on AEM, and then reading back to confirm in frames 100/632.
I believe the duplication is probably just generally shitty softwware reading things in multiple places?
After that, we just see the "normal" four chunk transfers starting at frame 3372

### The others
(I don't have exact details of them anymore, but current in the microamps, and aem-dump worked on them...)