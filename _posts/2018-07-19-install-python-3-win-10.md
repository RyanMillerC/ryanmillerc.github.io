---
layout: post
title: Install Python 3 Alongside Python 2 on Windows 10
---

I recently needed to test an application at work with Python 3. It’s a hard
requirement that I keep the ability to run Python 2 code for my job, so I
installed Python 3 alongside my existing Python 2 installation. Since it
required more work than just running the installer and calling it done, I
documented the process below.

This method does not require administrative privileges to install for your user
account, (it will if you need to install for all users on a machine, however).

The first step is to get Python 3 installed.

1. Get latest installer executable from: https://www.python.org/getit/
2. Launch the installer, un-check the box for “Install for all users”, and
   click install.

After the installer completes, Python will be installed in
`C:\Users\<YOUR-USER>\AppData\Local\Programs\Python\Python3<VERSION>`, and will
be automatically added to your PATH. Because Python 2’s directory is already in
your PATH and has a program under the same name ‘python.exe’, it will always
launch the old Python 2 executable. Let’s fix that.

1. Go into the Python 3 install directory (above) and copy `python.exe` to
   `python3.exe`
2. Open a new Powershell window and test with `python3 --version`.

> Pip 3 will be automatically get installed with the alias ‘pip3’ so
there is no need to worry about copying pip.exe.

Sweet! Python 3 is now installed alongside Python 2 and can easily called with
python3.

> When calling Python 3 modules, it’s usually a good idea to use
‘python3 -m module_name’, instead of any shell shorthand name because if you
have a module installed for Python 2, it will usually try to use that.
Example, virtualenv. Running virtualenv folder, from cmd or Powershell will
create a Python 2 virtual environment, whereas using python3 -m virtualenv
folder, will always create a Python 3 virtual environment.

Hopefully that helped you. If you encounter any errors I didn't account for,
let me know and I'll add it to this post.
