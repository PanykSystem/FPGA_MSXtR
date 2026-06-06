quietly WaveActivateNextPane {} 0
add wave -r *
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 240
configure wave -valuecolwidth 80
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits us
update
WaveRestoreZoom {0 ps} {500 us}