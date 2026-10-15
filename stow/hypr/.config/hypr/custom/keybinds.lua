hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

--# Screenshot keybinds
--# Both save a timestamped PNG to ~/Pictures/Screenshots and copy it to the clipboard
local shotDest = "d=\"$(xdg-user-dir PICTURES)/Screenshots\"; f=\"$d/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png\"; mkdir -p \"$d\" && "
local shotToClipboard = " && wl-copy -t image/png < \"$f\""
--# Confirm with a notification showing the capture itself as its thumbnail
local shotNotify = " && notify-send -a \"Screenshot\" -t 4000 -h \"string:image-path:file://$f\"" ..
    " \"Screenshot saved\" \"${f##*/}\""
local shotMonitor = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""

--# Whole screen: SUPER + PrtSc
hl.bind("SUPER + Print", hl.dsp.exec_cmd(shotDest .. shotMonitor .. " \"$f\"" .. shotToClipboard .. shotNotify),
    { locked = true, description = "Screenshot: Whole screen >> file & clipboard" })

--# Specific region: SUPER + SHIFT + PrtSc
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd(shotDest .. "grim -g \"$(slurp)\" \"$f\"" .. shotToClipboard .. shotNotify),
    { locked = true, description = "Screenshot: Region >> file & clipboard" })

--# Move the focused window to another workspace: SUPER + SHIFT + 1..9
--# The movewindow dispatcher only ever acts on the active window, never on the
--# rest of the workspace. follow = true moves you along with the window.
--# Set follow = false to leave the window behind and stay where you are.
local followWindow = true
local function sendActiveWindowTo(i)
    local win = hl.get_active_window()
    if not win then return end -- nothing focused, nothing to move
    hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = followWindow }))
end
for i = 1, 9 do
    hl.bind("SUPER + SHIFT + " .. i, function() sendActiveWindowTo(i) end,
        { description = "Window: Move active window to workspace " .. i })
end
--# Raw keycodes, because some layouts register number keys as different chars. Verify with `wev`
for i = 1, 9 do
    hl.bind("SUPER + SHIFT + code:" .. i + 9, function() sendActiveWindowTo(i) end)
end