
Create a container image for running Method R tools
===================================================

## Create the image

podman build -t mrtools-runner .

## Generate the wrapper scripts

`./generate-wrappers.sh`

## Run the container

Now there are wrapper scripts for each of the Method R tools in the current directory.

These lines in the wrapper script mount these directories in the container:

```bash
  -v "\$HOME/oracle":"\$HOME/oracle":z \\
  -v "\$HOME/tmp":"\$HOME/tmp":z \\
  -v "\$PWD":"\$PWD":z \\
  -w "\$PWD" \\
```

The container runs as root.

The `$HOME/oracle` directory is mounted read-write, so you can write output files there.

In my case, the container has the directories '/home/jkstill/oracle', '/home/jkstill/tmp'  and the current directory mounted read-write.

You can run them as you would normally, and they will execute inside the container. For example:

```bash

$ mrskew --version

```

```bash
$ mrskew some-trace-file.trc
```

If your get a pathing error, keep in mind where things are mounted. 

For example, if you have a trace file in the current directory, it will be available in the container at the same path. 

So if you are in `~/oracle` and you have a trace file there, it will be available in the container at `~/oracle/some-trace-file.trc`.


For example:

```bash
cd ~/oracle
mrskew oraaccess-xml/trace/orcl1901_ora_1359116_ARRAY-500.trc
```

## Run the container directly

Useful for debugging.

```bash
podman run --rm -it \
  -v /usr/share/mrtools:/usr/share/mrtools:ro,z \
  -v "$HOME/oracle":"$HOME/oracle":z \
  -v "$HOME/tmp":"$HOME/tmp":z \
  -v "$PWD":"$PWD":z \
  -w "$PWD" \
  -v "$HOME/.mrtools":/home/mruser/.mrtools:z \
  -v "$HOME/.mrskew.rc":/home/mruser/.mrskew.rc:ro,z \
  -v "$HOME/.method-r":/home/mruser/.method-r:z \
  -e HOME=/home/mruser \
  -e USER="$USER" \
  -e MRTOOLS_RCPATH=/home/mruser/.mrtools/rc:/usr/share/mrtools/rc \
  localhost/mrtools-runner
```

## Performance

The overhead of podmand is small:

Run with podman:

```bash
$  time /usr/local/bin/mrskew *.trc
CALL-NAME                                  DURATION       %      CALLS      MEAN       MIN        MAX
---------------------------------------  ----------  ------  ---------  --------  --------  ---------
SQL*Net message from client              186.309842   41.7%    302,003  0.000617  0.000000   0.202667
EXEC                                      92.788369   20.8%         62  1.496587  0.000000  56.711378
db file sequential read                   61.857551   13.9%    163,289  0.000379  0.000000   0.115173
FETCH                                     55.235720   12.4%    231,336  0.000239  0.000000   0.029995
direct path read                          18.794763    4.2%      1,653  0.011370  0.000000   0.078647
log buffer space                          16.338905    3.7%         43  0.379975  0.005662   2.531727
PX Deq: reap credit                        3.568401    0.8%     51,737  0.000069  0.000000   0.005703
log file switch (checkpoint incomplete)    3.140052    0.7%          4  0.785013  0.018724   3.063404
LOBREAD                                    2.343887    0.5%     70,465  0.000033  0.000000   0.014999
PX Deq: Execute Reply                      2.152756    0.5%     51,616  0.000042  0.000000   0.010088
42 others                                  3.889971    0.9%    303,307  0.000013  0.000000   0.426606
---------------------------------------  ----------  ------  ---------  --------  --------  ---------
TOTAL (52)                               446.420217  100.0%  1,175,515  0.000380  0.000000  56.711378

real  0m19.861s
user  0m0.054s
sys   0m0.203s


$  time /usr/local/bin/mrskew js01_ora_4466_CLOB-AL32UTF8.trc
CALL-NAME                    DURATION       %   CALLS      MEAN       MIN       MAX
---------------------------  --------  ------  ------  --------  --------  --------
SQL*Net message from client  5.342691   96.5%   6,484  0.000824  0.000023  0.022768
LOBREAD                      0.151981    2.7%   6,405  0.000024  0.000000  0.014999
ADR block file read          0.024166    0.4%       8  0.003021  0.000258  0.012540
SQL*Net message to client    0.007550    0.1%   6,485  0.000001  0.000000  0.000068
FETCH                        0.004998    0.1%      78  0.000064  0.000000  0.002999
EXEC                         0.001000    0.0%       2  0.000500  0.000000  0.001000
PARSE                        0.001000    0.0%       2  0.000500  0.000000  0.001000
db file scattered read       0.000849    0.0%      38  0.000022  0.000010  0.000101
Disk file operations I/O     0.000048    0.0%       1  0.000048  0.000048  0.000048
CLOSE                        0.000000    0.0%       1  0.000000  0.000000  0.000000
---------------------------  --------  ------  ------  --------  --------  --------
TOTAL (10)                   5.534283  100.0%  19,504  0.000284  0.000000  0.022768

real  0m1.247s
user  0m0.050s
sys   0m0.194s

```

Run natively:

```bash
$  time /usr/share/mrtools/bin/mrskew *.trc
CALL-NAME                                  DURATION       %      CALLS      MEAN       MIN        MAX
---------------------------------------  ----------  ------  ---------  --------  --------  ---------
SQL*Net message from client              186.309842   41.7%    302,003  0.000617  0.000000   0.202667
EXEC                                      92.788369   20.8%         62  1.496587  0.000000  56.711378
db file sequential read                   61.857551   13.9%    163,289  0.000379  0.000000   0.115173
FETCH                                     55.235720   12.4%    231,336  0.000239  0.000000   0.029995
direct path read                          18.794763    4.2%      1,653  0.011370  0.000000   0.078647
log buffer space                          16.338905    3.7%         43  0.379975  0.005662   2.531727
PX Deq: reap credit                        3.568401    0.8%     51,737  0.000069  0.000000   0.005703
log file switch (checkpoint incomplete)    3.140052    0.7%          4  0.785013  0.018724   3.063404
LOBREAD                                    2.343887    0.5%     70,465  0.000033  0.000000   0.014999
PX Deq: Execute Reply                      2.152756    0.5%     51,616  0.000042  0.000000   0.010088
42 others                                  3.889971    0.9%    303,307  0.000013  0.000000   0.426606
---------------------------------------  ----------  ------  ---------  --------  --------  ---------
TOTAL (52)                               446.420217  100.0%  1,175,515  0.000380  0.000000  56.711378

real  0m18.984s
user  0m6.542s
sys   0m1.158s


jkstill@poirot /mnt/zips/tmp/Method-R $
$  time /usr/share/mrtools/bin/mrskew js01_ora_4466_CLOB-AL32UTF8.trc
CALL-NAME                    DURATION       %   CALLS      MEAN       MIN       MAX
---------------------------  --------  ------  ------  --------  --------  --------
SQL*Net message from client  5.342691   96.5%   6,484  0.000824  0.000023  0.022768
LOBREAD                      0.151981    2.7%   6,405  0.000024  0.000000  0.014999
ADR block file read          0.024166    0.4%       8  0.003021  0.000258  0.012540
SQL*Net message to client    0.007550    0.1%   6,485  0.000001  0.000000  0.000068
FETCH                        0.004998    0.1%      78  0.000064  0.000000  0.002999
EXEC                         0.001000    0.0%       2  0.000500  0.000000  0.001000
PARSE                        0.001000    0.0%       2  0.000500  0.000000  0.001000
db file scattered read       0.000849    0.0%      38  0.000022  0.000010  0.000101
Disk file operations I/O     0.000048    0.0%       1  0.000048  0.000048  0.000048
CLOSE                        0.000000    0.0%       1  0.000000  0.000000  0.000000
---------------------------  --------  ------  ------  --------  --------  --------
TOTAL (10)                   5.534283  100.0%  19,504  0.000284  0.000000  0.022768

real  0m0.762s
user  0m0.336s
sys   0m0.035s

```

