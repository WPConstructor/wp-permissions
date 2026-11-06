# WPConstructor Permissions

**Shared Linux Permissions Manager for WordPress Development**

WPConstructor Permissions is a Bash utility designed to configure shared file and directory permissions for WordPress installations.

It allows your Linux user and your web server user (Apache/PHP) to access and modify the same WordPress files without constantly changing ownership or permissions.

Designed primarily for local WordPress development environments such as XAMPP.

---

## Features

- Automatic detection of the current Linux user.
- Web server user validation.
- Interactive prompt if the configured web server user does not exist.
- Persistent configuration stored in `permissions.conf`.
- Automatic creation of a shared Linux group.
- Automatic group membership configuration.
- Recursive ownership configuration.
- Directory and file permission management.
- Access Control List (ACL) support.
- Default ACLs for newly created files and directories.
- Suitable for local WordPress development environments.

---

## Requirements

- Linux operating system.
- Bash.
- Root or sudo privileges.
- Existing Linux user account.
- Existing web server user account.
- `getent`, `groupadd`, `usermod`, `chown`, `chmod`, `find`.
- `setfacl` (recommended).

### Install ACL support

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

## Installation

Clone or download the project.

### Directory structure

```text
WPConstructor-Permissions/
│
├── permissions.sh
├── permissions.conf
└── README.md
```

Make the script executable:

```bash
chmod +x permissions.sh
```

The configuration file is automatically created during the first execution if it does not already exist.

---

## Usage

Run the script with sudo and specify your WordPress installation directory:

```bash
sudo ./permissions.sh /path/to/wordpress
```

### Example: XAMPP

```bash
sudo ./permissions.sh /opt/lampp/htdocs/wpconstructor
```

The script will:

1. Detect the original Linux user.
2. Load the saved configuration.
3. Check whether the configured web server user exists.
4. Prompt for a valid web server username if necessary.
5. Create the shared group if it does not exist.
6. Add both users to the shared group.
7. Configure ownership and permissions.
8. Apply ACLs if available.
9. Save the configuration.

---

## Configuration

The script uses:

`permissions.conf`

Example:

```bash
OWNER="john-melt"
WEBUSER="daemon"
SHARED_GROUP="wp-shared"
```

### Configuration options

| Variable       | Description                                |
| -------------- | ------------------------------------------ |
| `OWNER`        | Linux user who manages the WordPress files |
| `WEBUSER`      | Apache/PHP execution user                  |
| `SHARED_GROUP` | Shared Linux group                         |

### Automatic user detection

If `OWNER` is empty, the script detects the original user using:

```bash
OWNER="${SUDO_USER:-}"
```

This ensures that executing the script with sudo does not accidentally assign ownership to root.

### Web server user

The default web server user is:

```bash
WEBUSER="daemon"
```

If this account does not exist, the script asks you to enter a valid username.

Possible usernames include:

- `daemon`
- `www-data`
- `apache`

The correct username depends on your web server configuration.

For XAMPP, check the Apache process:

```bash
ps -eo user,comm | grep -E 'httpd|apache2'
```

---

## Permission Structure

The script uses a shared Linux group.

Example:

```text
john-melt ─────┐
               ├── wp-shared
daemon ────────┘
```

Both users receive shared access through this group.

### Directory permissions

```bash
chmod 2770
```

Meaning:

| Permission | Owner | Group | Others |
| ---------- | ----- | ----- | ------ |
| Read       | Yes   | Yes   | No     |
| Write      | Yes   | Yes   | No     |
| Execute    | Yes   | Yes   | No     |

The leading `2` enables the setgid bit.

This ensures that newly created files and directories inherit the parent directory's group.

### File permissions

```bash
chmod 0660
```

Meaning:

| Permission | Owner | Group | Others |
| ---------- | ----- | ----- | ------ |
| Read       | Yes   | Yes   | No     |
| Write      | Yes   | Yes   | No     |
| Execute    | No    | No    | No     |

---

## ACL Support

When `setfacl` is installed, the script additionally configures Access Control Lists.

ACLs provide more granular permissions for individual users.

The script applies:

- Read and write permissions for the owner.
- Read and write permissions for the web server user.
- Shared group permissions.
- Default ACLs for new files and directories.

This helps maintain shared access even when files are created by different processes.

Check ACL permissions:

```bash
getfacl /path/to/wordpress
```

---

## Group Membership

After adding users to a group, existing processes do not automatically receive the updated group membership.

For your current terminal session:

```bash
newgrp wp-shared
```

For Apache/XAMPP:

```bash
sudo /opt/lampp/lampp restart
```

You can verify group membership using:

```bash
groups john-melt
groups daemon
```

Replace the usernames with the actual configured accounts.

---

## Troubleshooting

### Permission denied

Check ownership:

```bash
ls -la /path/to/wordpress
```

Check group membership:

```bash
getent group wp-shared
```

Check ACLs:

```bash
getfacl /path/to/wordpress
```

### Apache cannot write files

Verify the actual Apache execution user:

```bash
ps aux | grep httpd
```

Check whether that user belongs to the shared group:

```bash
id daemon
```

Replace `daemon` with your actual web server user.

Restart Apache after changing group membership.

### ACL support is missing

Install the ACL package for your Linux distribution and execute the script again.

---

## Security Considerations

**WPConstructor Permissions is intended primarily for local development environments.**

The script grants the web server user write access to the entire specified WordPress directory.

This is convenient for development but is not recommended for production environments.

For production installations:

- Keep WordPress core files protected.
- Restrict write access to necessary directories.
- Avoid giving Apache unrestricted write access to PHP files.
- Keep configuration files protected.
- Maintain regular backups.

The script also changes ownership recursively throughout the specified directory.

Always verify the target path before execution.

---

## Configuration File Security

The configuration file is protected using:

```bash
chmod 600 permissions.conf
```

Only its owner can read or modify it.

The configuration file is loaded using Bash `source`, so only use trusted configuration files.

---

## License

MIT

---

## WPConstructor

**WPConstructor Permissions**

A utility for simplifying WordPress development workflows on Linux.

Built for developers who want a clean and reliable shared-permission setup between their Linux account and web server.
