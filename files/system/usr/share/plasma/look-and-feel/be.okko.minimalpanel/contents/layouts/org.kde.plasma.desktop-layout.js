var panel = new Panel
panel.height = 2 * Math.floor(gridUnit * 2.5 / 2)
panel.location = "bottom"

panel.addWidget("org.kde.plasma.kickoff")

var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", [
    "applications:org.kde.krdc.desktop"
])

panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.digitalclock")
panel.addWidget("org.kde.plasma.showdesktop")