# Don’t clear the screen after quitting a manual page.
export MANPAGER='less -X';

# Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.
export PYTHONIOENCODING='UTF-8';

# Prefer US English and use UTF-8.
export LANG='en_US.UTF-8';
export LC_ALL='en_US.UTF-8';

# For scala. See http://stackoverflow.com/questions/41193331/getting-cat-release-no-such-file-or-directory-when-running-scala
export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
