# WPConstructor WP Permissions

v0.1.0

**Shared Linux Permissions Manager for WordPress Development**

WPConstructor WP Permissions is a Bash utility that configures shared file and directory permissions for local WordPress development.

It allows your local Linux user and your Apache/PHP web server user to access and modify the same WordPress installation without constantly changing file ownership or permissions manually.

---

## Features

- Automatically detects your Linux username when executed with `sudo`.
- Supports a configurable Apache/PHP web server user.
- Creates and manages a shared Linux group.
- Adds the required users to the shared group.
- Sets appropriate ownership and permissions recursively.
- Enables the setgid bit on directories for shared group inheritance.
- Supports Access Control Lists (ACLs).
- Continues to work without ACL support using standard Unix permissions.
- Saves configuration settings for future use.
- Checks the target directory before applying changes.
- Provides confirmation before modifying file permissions.
- Supports `--help` and `--version` options.

---

## Requirements

- Linux operating system.
- Bash.
- Root privileges (`sudo`).
- A WordPress installation.
- Standard Linux utilities used by the script.
- `acl` package (optional, but recommended).

---

## Installation

Clone or download the repository:

```bash
git clone https://github.com/YOUR-USERNAME/wp-permissions.git
```

Enter the project directory:

```bash
cd wp-permissions
```

Make the script executable:

```bash
chmod +x wp-permissions.sh
```

---

## Install ACL support

### Why use ACL?

ACL stands for *Access Control Lists*. It allows permissions to be assigned to specific users and groups in addition to standard Linux ownership and group permissions.

This is useful when your local Linux user and Apache/PHP run under different accounts but both need access to the same WordPress files.

ACLs also allow default permissions to be inherited by newly created files and directories.

### When is ACL not necessary?

ACL support is optional. If standard Unix permissions and a shared group provide everything you need, you do not need ACLs.

**The script will continue to work without ACL support, using standard Unix permissions instead. However, individual user permissions and default ACL inheritance will not be available.**

### Check if ACL is installed

Run the following commands:

setfacl --version
getfacl --version

If both commands display version information, the ACL utilities are installed.

If you see command not found, install the acl package for your Linux distribution.

Note: Having the ACL utilities installed does not necessarily mean your filesystem currently supports ACLs. Filesystem support and mount options also matter.

### Install the `acl` package if it is missing:

**Debian / Ubuntu**

```bash
sudo apt install acl
```

**Fedora**

```bash
sudo dnf install acl
```

**Arch Linux**

```bash
sudo pacman -S acl
```

---

## Project structure

The project contains the following files:

```text
wp-permissions/
├── wp-permissions.sh
├── wp-permissions.conf
├── README.md
└── LICENSE
```

The configuration file is created automatically when the script is run.

---

## Usage

Run the script with `sudo` and provide the path to your WordPress installation:

```bash
sudo ./wp-permissions.sh /path/to/wordpress
```

Example for XAMPP:

```bash
sudo ./wp-permissions.sh /opt/lampp/htdocs/wordpress
```

The script checks the target directory and asks for confirmation before applying permission changes.

### How often should you run the script?

Normally, you only need to run wp-permissions.sh once per WordPress installation.

Run it again if ownership, permissions, group membership, or configuration changes, or if restored files have incorrect permissions.

### Global command

You can make the command available system-wide by creating a symbolic link:

```bash
sudo ln -s "$(realpath wp-permissions.sh)" /usr/local/bin/wp-permissions
```

You can then run it from any directory:

```bash
sudo wp-permissions /path/to/wordpress
```

---

## Configuration

The script uses `wp-permissions.conf` to store its settings.

Example:

```bash
OWNER="john-melt"
WEBUSER="daemon"
SHARED_GROUP="wp-shared"
```

### Configuration options

| Option         | Description                                  |
| -------------- | -------------------------------------------- |
| `OWNER`        | Your local Linux username.                   |
| `WEBUSER`      | The Apache/PHP web server user.              |
| `SHARED_GROUP` | The shared Linux group used for permissions. |

If `OWNER` is not configured, the script attempts to detect the username that invoked `sudo`.

**Important:** The web server user depends on your Linux distribution and development environment.

For XAMPP, `daemon` is commonly used, but you should verify the actual Apache worker user on your system.

---

## How permissions work

The script creates a shared group and adds both the local Linux user and the web server user to it.

The default configuration uses:

```text
Owner:        john-melt
Web user:     daemon
Shared group: wp-shared
```

### Directory permissions

Directories receive:

```text
2770
```

This provides:

- Full access to the owner.
- Full access to the shared group.
- No access for other users.
- Setgid enabled so new files and directories inherit the parent directory's group.

### File permissions

Regular non-executable files receive:

```text
0660
```

This provides:

- Read and write access for the owner.
- Read and write access for the shared group.
- No permissions for other users.

Executable files retain executable access while receiving the configured shared-group permissions.

### ACL permissions

When `setfacl` is available, the script additionally configures ACL entries for the local user, web server user, and shared group.

Default ACLs are applied to directories to help new files and directories inherit the intended access permissions.

If ACL utilities are unavailable, the script skips ACL configuration and continues with standard Unix permissions.

---

## Important: Group membership

After adding users to a shared group, their existing processes may not automatically recognize the new membership.

You may need to:

1. Log out and log back in, or start a new session.
2. Restart Apache/XAMPP so its processes use the updated group membership.

For XAMPP:

```bash
sudo /opt/lampp/lampp restart
```

You can check a user's group membership with:

```bash
id username
```

---

## Safety information

**Use this script only on WordPress development directories that you intend to modify.**

The script performs recursive ownership and permission changes on the selected target directory.

Before running it:

- Verify that the target path is correct.
- Make sure you have a backup.
- Check that the configured users and group are correct.
- Understand that existing ownership and permissions will be changed.

The script uses `find` with `-xdev` to avoid traversing into other mounted filesystems.

It does not provide a complete rollback mechanism. Changes to ownership, permissions, group membership, or configuration may remain if execution is interrupted.

---

## Troubleshooting

### Permission denied

Check the ownership and permissions:

```bash
ls -la /path/to/wordpress
```

Check group membership:

```bash
id username
```

Make sure Apache/XAMPP has been restarted after group membership changes.

### ACL commands not found

Install the `acl` package for your distribution.

Check whether the utilities are available:

```bash
setfacl --version
getfacl --version
```

If ACL utilities are unavailable, the script uses standard Unix permissions instead.

### Apache cannot write to WordPress files

Check the actual Apache/PHP user and verify that it belongs to the shared group.

You can inspect the configured group with:

```bash
getent group wp-shared
```

---

## Security

This utility is intended for local WordPress development environments.

The default directory permissions grant full access to the owner and shared group while denying access to other users.

Do not use these settings blindly on production servers or directories that require different access policies.

Always verify the configured web server user and target directory before proceeding.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**WPConstructor WP Permissions**
*Simple, consistent, shared permissions for local WordPress development.*
