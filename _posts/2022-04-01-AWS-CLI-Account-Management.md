---
layout: post
title:  "AWS CLI Account Management"
---

I recently needed to manage multiple AWS accounts from the same machine. AWS CLI supports this using *[Profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)*. AWS account profiles are configured in `~/.aws/credentials`. For example:

```ini
[default]
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
region=us-east-1
output=json

[account_1]
aws_access_key_id=AKIAI44QH8DHBEXAMPLE
aws_secret_access_key=je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
region=us-east-2
output=json
```

AWS CLI defaults to using the `default` account for commands run without specifying a profile. 

AWS CLI accepts a `—profile profile_name` option to specify the account to run that command against:

```bash
$ aws —profile account_1 s3 ls
```

AWS CLI will also check the value of the `AWS_PROFILE` environment variable to determine which account credentials to use. This can be set with:

```bash
$ export AWS_PROFILE="account_1"
```

I wrote this bash function to switch between accounts:

```bash
aws-profile() { export AWS_PROFILE="$1"; }
```

To use the function: Add the above line to your `~/.bashrc`, reload your shell, and run:

```bash
$ aws-profile account_a
```
