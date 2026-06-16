
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


