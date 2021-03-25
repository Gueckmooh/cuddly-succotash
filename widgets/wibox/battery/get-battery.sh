BAT=$(acpi -b | grep -v unavailable)
ADP=$(acpi -a)

echo $BAT // $ADP
