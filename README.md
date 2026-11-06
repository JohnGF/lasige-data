# lasige-data

Gets data onto the LASIGE cluster without loading the login node. Downloads run as
Slurm jobs on a compute node, and uploads from your machine are throttled.

## Getting started

1. Connect to the FCUL VPN.
2. Check that this works: `ssh <your_username>@login-node.di.fc.ul.pt`
3. If your SSH config doesn't set your username, add it to
   `~/.config/lasige-data/config`:

   ```ini
   user = <your_username>
   ```

4. Try it:

   ```bash
   ./lasige-data status
   ./lasige-data hf org/name
   ./lasige-data push ./my_data
   ```

Run `./lasige-data --help` for what each command does and what it doesn't guarantee.

`push` needs `rsync` on your machine and hasn't been tested on Windows.
