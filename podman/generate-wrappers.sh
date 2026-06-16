#!/usr/bin/env bash

for cmd in mr1011 mrcrop mrkey mrprof mrprofk mrskew mrwhen; do
  sudo tee /usr/local/bin/$cmd >/dev/null <<EOF
#!/usr/bin/env bash
exec podman run --rm -i \\
  -v /usr/share/mrtools:/usr/share/mrtools:ro,z \\
  -v "\$HOME/":"\$HOME/":z \\
  -v "\$PWD":"\$PWD":z \\
  -w "\$PWD" \\
  -v "\$HOME/.mrtools":/home/mruser/.mrtools:z \\
  -v "\$HOME/.mrskew.rc":/home/mruser/.mrskew.rc:ro,z \\
  -v "\$HOME/.method-r":/home/mruser/.method-r:z \\
  -e HOME=/home/mruser \\
  -e USER="\$USER" \\
  -e MRTOOLS_RCPATH=/home/mruser/.mrtools/rc:/usr/share/mrtools/rc \\
  localhost/mrtools-runner \\
  /usr/share/mrtools/bin/$cmd "\$@"
EOF
  sudo chmod 755 /usr/local/bin/$cmd
done

# GUI tools
#
for cmd in  mrworkbench; do
  sudo tee /usr/local/bin/$cmd >/dev/null <<EOF
#!/usr/bin/env bash
exec nohup podman run --rm -it \\
  -v /usr/share/mrtools:/usr/share/mrtools:ro,z \\
  -v "\$HOME/":"\$HOME/":z \\
  -v "\$PWD":"\$PWD":z \\
  -w "\$PWD" \\
  -v "\$HOME/.mrtools":/home/mruser/.mrtools:z \\
  -v "\$HOME/.mrskew.rc":/home/mruser/.mrskew.rc:ro,z \\
  -v "\$HOME/.method-r":/home/mruser/.method-r:z \\
  -e HOME=/home/mruser \\
  -e USER="\$USER" \\
  -e DISPLAY="\$DISPLAY" \\
  -e XAUTHORITY=/home/mruser/.Xauthority \\
  -v "\${XAUTHORITY:-\$HOME/.Xauthority}":/home/mruser/.Xauthority:ro,z \\
  --network host \\
  -e MRTOOLS_RCPATH=/home/mruser/.mrtools/rc:/usr/share/mrtools/rc \\
  localhost/mrtools-runner \\
  /usr/share/mrtools/bin/$cmd "\$@" \\
  2>/dev/null &
EOF
  sudo chmod 755 /usr/local/bin/$cmd
done

