# One-click installer that calls the other scripts

# The order must be:
# install_omnet.sh
# install_inet.sh
# install_inet_extensions.sh
# install_raynet

# The order within inet_extensions shouldn't matter much, may need to tweak it later.

# Make this into a one-run run script that attempts to install all the components.
# Each install script should first verify that the componenet being installed does not already exist
# Maybe add a quick series of y/n questiosn to verify which componenets the user wants installed.
# DO you want omnet? y/n
# Do you want inet? y/n
# do you want inet_extensions? y/n
# Do you want raynet? y/n
# etc. Make it look nicer than the questions I've written.
