---
layout: post
title: Use GPG Signing Keys with Git (and GitHub) on Windows 10
---

**This is a repost from Medium - [Original
Link](https://medium.com/@ryanmillerc/use-gpg-signing-keys-with-git-on-windows-10-github-4acbced49f68).**

Setting up GPG keys with Git on Windows can be more difficult to configure than
on Mac OS or Linux. Here's how to set it up.

1. Download and install GPG4Win: https://www.gpg4win.org/get-gpg4win.html (Use
   local account when prompted to avoid admin!)
2. Create a GPG key using this GitHub guide, (Make sure to also follow along
   with the steps to upload your GPG key if using GitHub).
3. Next, open up a new Powershell window and run `where.exe gpg` to get the exact
   location of the GPG program installed withGPG4Win.
4. Take the output from the previous command and put it into: `git config
   --global gpg.program [PATH_HERE]`, (Make sure to replace `"PATH_HERE"` with
   output from previous command).

Great! Now you have configured your GPG key and told Git what program to use to
open it. The next section shows how to actually sign code.

You have two options for signing commits and tags. You can either force signing
for all Git projects with the `--global` flag, or force signing for specific
projects with the `--local` flag. Since I have some projects that don't require
code signing, I'm going to use the local option. I've `cd`'ed into my Git project
directory and I'm ready to commit some changes. Before I can commit, I need to
tell Git that this project uses a GPG key for code signing.

1. First, force Git to sign all commits in this project: `git config --local
   commit.gpgsign true`.
2. Then, get the ID of your GPG key: `gpg --list-secret-keys --keyid-format
   LONG`.
3. Add that ID from above to your Git config: `git config --local
   user.signingkey "[GPG_KEY]"`, (Make sure to replace `GPG_KEY` with the ID
   from your GPG key in the previous command)

Awesome! Now that the project is configured to use GPG keys to sign code, I can
commit code like normal, e.g. `git commit -m "Changed x code to y"`.

> One thing to keep in mind is that GitHub requires the email on your
key and in your Git config to match your GitHub email address. To set that
in Git, use: `git config --global user.email "YOUR@EMAIL.com"`.

Hopefully that helped you. If you encounter any errors I didn't account for,
let me know and I'll add it to this post.
