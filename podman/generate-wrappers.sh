#!/usr/bin/env bash

for cmd in mr1011 mrcrop mrkey mrprof mrprofk mrskew mrwhen; do
  sudo tee /usr/local/bin/$cmd >/dev/null <<EOF
#!/usr/bin/env bash
# pass exported MRTOOLS_* variables (e.g. MRTOOLS_DEBUG, MRTOOLS_ARRAYSIZE) into the container
# MRTOOLS_RCPATH is excluded, as it must point to container paths (set below)
env_args=()
for v in \$(compgen -e); do
  [[ \$v == MRTOOLS_* && \$v != MRTOOLS_RCPATH ]] && env_args+=(-e "\$v")
done
exec podman run --rm -i \\
  "\${env_args[@]}" \\
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

