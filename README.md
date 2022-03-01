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

### Building
Needs *libjaylink* and a C compiler.
libjaylink-devel is available for fedora at least, if not, get it from [libjaylink](https://gitlab.zapb.de/libjaylink/libjaylink)

## wireshark usb decoder for jlink traffic

it's not _remotely_ finished, but the stub is there to plug in a statemachine....
