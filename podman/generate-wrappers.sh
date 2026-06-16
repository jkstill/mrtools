#!/usr/bin/env bash


for cmd in mr1011 mrcrop mrkey mrprof mrprofk mrskew mrwhen mrworkbench; do
  sudo tee /usr/local/bin/$cmd >/dev/null <<EOF
#!/usr/bin/env bash
exec podman run --rm -i \\
  -v /usr/share/mrtools:/usr/share/mrtools:ro,z \\
  -v "\$PWD":"\$PWD":z \\
  -w "\$PWD" \\
  -v "\$HOME/.method-r":"\$HOME/.method-r":z \\
  -e HOME="\$HOME" \\
  localhost/mrtools-runner \\
  $cmd "\$@"
EOF
  sudo chmod 755 /usr/local/bin/$cmd
done


