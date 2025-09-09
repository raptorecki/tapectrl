#!/bin/bash

# Set a compatible terminal type
export TERM=xterm

# tapectrl - LTO Tape Control Utility
VERSION="1.0.2"
TAPE_DEVICE="/dev/nst0"
DIALOG_HEIGHT=24
DIALOG_WIDTH=70
BOX_HEIGHT=18
BOX_WIDTH=68

# Define the logo as a global variable for reuse
# Using $'...' for ANSI C-style quoting to interpret \n as actual newlines
LOGO_ART=$'  __                               __         .__   \n_/  |______  ______   ____   _____/  |________|  |  \n\   __\__  \ \____ \_/ __ \_/ ___\   __\_  __ \  |  \n |  |  / __ \|  |_> >  ___/\  \___|  |  |  | \/  |__\n |__| (____  /   __/ \___  >\___  >__|  |__|  |____/\n           \/|__|        \/     \/                  '

# Set DIALOGRC to our theme file
# export DIALOGRC=/home/marecki/tapectrl/.dialogrc

# --- Dependency Check ---
check_deps() {
    local missing_deps=()
    for cmd in dialog mt mbuffer dd tar; do
        if ! command -v "$cmd" &> /dev/null;
then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them to continue. (e.g., sudo apt-get install dialog mt-st mbuffer)"
        exit 1
    fi
}

# --- UI Functions ---
show_infobox() {
    dialog --title "INFO" --infobox "$1" 5 50
    sleep 2
}

show_msgbox() {
    dialog --title "$1" --msgbox "$2" 10 60
}

show_yesno() {
    dialog --title "$1" --yesno "$2" 10 70
    return $?
}

show_appinfobox() {
    dialog --title "$1" --msgbox "$2" 16 80
}

# This function is for commands where we want to show the output in a box
run_command_programbox() {
    local title="$1"
    local cmd="$2"
    local temp_err
    temp_err=$(mktemp 2>/dev/null) || temp_err=/tmp/err$$

    { eval "$cmd"; } 2> "$temp_err" | dialog --title "$title" --programbox "$BOX_HEIGHT" "$BOX_WIDTH" < /dev/null
    
    local cmd_exit_status=${PIPESTATUS[0]}
    local err_output
    err_output=$(<$temp_err)
    rm -f "$temp_err"

    if [ $cmd_exit_status -ne 0 ]; then
        show_msgbox "Error" "Command failed with exit code $cmd_exit_status.\n\nError output:\n$err_output"
    else
        show_msgbox "Success" "Operation completed successfully."
    fi
}

# This function is for short commands where we just show the result text
run_command_msgbox() {
    local title="$1"
    local cmd="$2"
    local success_msg="$3"
    
    output=$(eval "$cmd" 2>&1)
    local exit_status=$?

    if [ $exit_status -ne 0 ]; then
        show_msgbox "Error" "Command failed with exit code $exit_status.\n\nOutput:\n$output"
    else
        if [ -n "$success_msg" ]; then
            show_msgbox "$title" "$success_msg\n\nOutput:\n$output"
        else
            show_msgbox "$title" "$output"
        fi
    fi
}

# A robust way to get input from dialog boxes (menu, inputbox, etc.)
run_dialog_capture() {
    local tempfile
    tempfile=$(mktemp 2>/dev/null) || tempfile=/tmp/dialog_$$

    dialog "${@}" 2> "$tempfile"
    local exit_code=$?

    DIALOG_RESULT=$(<$tempfile)
    rm -f "$tempfile"

    # Pass the exit code back to the caller
    return $exit_code
}


# --- Menu Functions ---

write_to_tape() {
    local explanation="This command writes files from a specified source directory to the tape."
    run_dialog_capture --title "Write To Tape" --inputbox "$explanation\n\nEnter the full path to the source directory:" 12 "$DIALOG_WIDTH"
    if [ $? -ne 0 ] || [ -z "$DIALOG_RESULT" ]; then
        show_infobox "Operation Cancelled."
        return
    fi
    local path="$DIALOG_RESULT"
    path_no_slash="${path%/}"

    if [ ! -d "$path_no_slash" ]; then
        show_msgbox "Error" "Directory '$path_no_slash' not found."
        return
    fi

    ( tar -cvf - -C "$path_no_slash" . | mbuffer -s 256k -m 2G | dd of=$TAPE_DEVICE bs=256k ) &> /tmp/tapectrl_write.log &
    local write_pid=$!

    echo "0" | dialog --title "Writing to Tape" --gauge "Write operation started (PID: $write_pid).\nLog: /tmp/tapectrl_write.log\nThis window will close upon completion." 12 70 0
    
    wait $write_pid
    local exit_status=$?
    
    if [ $exit_status -eq 0 ]; then
        show_msgbox "Success" "Writing Complete."
    else
        show_msgbox "Error" "Write operation failed. Exit code: $exit_status\n\nCheck /tmp/tapectrl_write.log for details."
    fi
}

rewind_tape() {
    local explanation="Rewinds the tape to the beginning of tape (BOT)."
    if show_yesno "Rewind Tape" "$explanation\n\nDo you want to proceed?"; then
        run_command_msgbox "Rewind Tape" "mt -f $TAPE_DEVICE rewind" "Tape successfully rewound."
    fi
}

verify_archive() {
    local explanation="Reads the tape from the current position and lists the files in the archive."
    show_msgbox "Verify Archive" "$explanation"
    run_command_programbox "Verifying Archive" "dd if=$TAPE_DEVICE bs=256k | tar -tvf -"
}

restore_from_tape() {
    local explanation="This will restore files from the beginning of the tape to a specified directory."
    run_dialog_capture --title "Restore From Tape" --inputbox "$explanation\n\nEnter the full path for the restore directory:" 12 "$DIALOG_WIDTH"
    if [ $? -ne 0 ] || [ -z "$DIALOG_RESULT" ]; then
        show_infobox "Operation Cancelled."
        return
    fi
    local restore_path="$DIALOG_RESULT"

    if ! show_yesno "Confirm Restore" "This will rewind the tape and restore its contents to:\n\n$restore_path\n\nThis may overwrite files in that directory. Proceed?"; then
        show_infobox "Operation Cancelled."; return
    fi

    if ! mkdir -p "$restore_path"; then
        show_msgbox "Error" "Could not create directory: $restore_path"; return
    fi

    show_infobox "Rewinding tape...\nYou may be prompted for a password for sudo."
    local rewind_output
    rewind_output=$(sudo mt -f "$TAPE_DEVICE" rewind 2>&1)
    if [ $? -ne 0 ]; then
        show_msgbox "Error" "Failed to rewind tape.\n\nOutput:\n$rewind_output"; return
    fi
    show_infobox "Tape rewound successfully."

    # Execute restore, merging stderr with stdout to show both tar and mbuffer output
    local cmd="(cd \"$restore_path\" && sudo dd if=$TAPE_DEVICE bs=256k | mbuffer -m 2G | tar -xvf -)"
    { eval "$cmd"; } 2>&1 | dialog --title "Restoring Files to $restore_path" --programbox "$BOX_HEIGHT" "$BOX_WIDTH" < /dev/null

    # Check the exit status of all commands in the pipeline
    local pipe_status=("${PIPESTATUS[@]}")
    local dd_ec=${pipe_status[0]}
    local mbuffer_ec=${pipe_status[1]}
    local tar_ec=${pipe_status[2]}

    if [ $dd_ec -ne 0 ] || [ $mbuffer_ec -ne 0 ] || [ $tar_ec -ne 0 ]; then
        show_msgbox "Error" "An error occurred during restore.\n\nExit Codes:\n- dd: $dd_ec\n- mbuffer: $mbuffer_ec\n- tar: $tar_ec"
    else
        show_msgbox "Success" "Restore operation completed successfully."
    fi
}

clean_drive() {
    local explanation="This command initiates a cleaning cycle for the tape drive."
    if show_yesno "Drive Clean" "$explanation\n\nIs the cleaning tape inserted? Do you want to proceed?"; then
        run_command_msgbox "Drive Clean" "mt -f $TAPE_DEVICE clean" "Drive Clean Completed."
    fi
}

erase_tape() {
    local explanation="This will completely and IRREVERSIBLY erase the entire tape."
    if show_yesno "Erase Tape" "$explanation\n\nARE YOU SURE YOU WANT TO ERASE THE TAPE?"; then
        run_command_msgbox "Erase Tape" "mt -f $TAPE_DEVICE erase" "Tape Erase Completed."
    fi
}

drive_status() {
    local explanation="Retrieves and displays the current status of the tape drive."
    show_msgbox "Drive Status" "$explanation"
    run_command_msgbox "Drive Status" "mt -f $TAPE_DEVICE status"
}

offline_tape() {
    local explanation="Rewinds the tape and then ejects it from the drive."
    if show_yesno "Offline Tape" "$explanation\n\nDo you want to rewind and eject the tape?"; then
        run_command_msgbox "Offline Tape" "mt -f $TAPE_DEVICE offline" "Tape is now offline."
    fi
}

tape_movement_menu() {
    while true; do
        run_dialog_capture --clear --backtitle "tapectrl v$VERSION" \
            --title "Tape Movement" \
            --menu "Select a tape movement operation:" \
            $DIALOG_HEIGHT $DIALOG_WIDTH 5 \
            "1" "Fast Forward to EOD" \
            "2" "Forward Space Files (fsf)" \
            "3" "Backward Space Files (bsf)" \
            "4" "Absolute Space to File (asf)" \
            "Back" "Return to Main Menu"
        
        if [ $? -ne 0 ]; then break; fi
        local choice="$DIALOG_RESULT"

        case $choice in
            1)
                if show_yesno "Fast Forward to EOD" "Moves tape to the end of recorded data.\n\nProceed?"; then
                    run_command_msgbox "Fast Forward to EOD" "mt -f $TAPE_DEVICE eod" "Tape moved to EOD."
                fi
                ;;
            2)
                run_dialog_capture --title "Forward Space Files" --inputbox "Moves forward a specified number of file marks.\n\nEnter number of files:" 10 "$DIALOG_WIDTH"
                if [ $? -ne 0 ]; then continue; fi
                local num="$DIALOG_RESULT"
                if [[ $num =~ ^[0-9]+$ ]]; then
                    run_command_msgbox "Forward Space Files" "mt -f $TAPE_DEVICE fsf $num" "Operation complete."
                elif [ -n "$num" ]; then show_msgbox "Error" "Invalid input."; fi
                ;;
            3)
                run_dialog_capture --title "Backward Space Files" --inputbox "Moves backward a specified number of file marks.\n\nEnter number of files:" 10 "$DIALOG_WIDTH"
                if [ $? -ne 0 ]; then continue; fi
                local num="$DIALOG_RESULT"
                if [[ $num =~ ^[0-9]+$ ]]; then
                    run_command_msgbox "Backward Space Files" "mt -f $TAPE_DEVICE bsf $num" "Operation complete."
                elif [ -n "$num" ]; then show_msgbox "Error" "Invalid input."; fi
                ;;
            4)
                run_dialog_capture --title "Absolute Space to File" --inputbox "Moves to an absolute file mark from BOT.\n\nEnter file number:" 10 "$DIALOG_WIDTH"
                if [ $? -ne 0 ]; then continue; fi
                local num="$DIALOG_RESULT"
                if [[ $num =~ ^[0-9]+$ ]]; then
                    run_command_msgbox "Absolute Space to File" "mt -f $TAPE_DEVICE asf $num" "Operation complete."
                elif [ -n "$num" ]; then show_msgbox "Error" "Invalid input."; fi
                ;;
            "Back") break ;; 
        esac
    done
}

write_eof() {
    run_dialog_capture --title "Write End Of File" --inputbox "Writes a specified number of End-Of-File (EOF) marks.\n\nEnter number of EOF marks to write:" 10 "$DIALOG_WIDTH"
    if [ $? -ne 0 ]; then show_infobox "Operation Cancelled."; return; fi
    local num="$DIALOG_RESULT"

    if [[ $num =~ ^[0-9]+$ ]]; then
        run_command_msgbox "Write End Of File" "mt -f $TAPE_DEVICE weof $num" "EOF marks written."
    elif [ -n "$num" ]; then show_msgbox "Error" "Invalid input."; fi
}

retension_tape() {
    local explanation="This winds the tape to the end and rewinds it, restoring proper tension."
    if show_yesno "Retension Tape" "$explanation\n\nThis can take a while. Do you want to proceed?"; then
        run_command_msgbox "Retension Tape" "mt -f $TAPE_DEVICE retension" "Tape retension completed."
    fi
}

show_info() {
    local logo="$LOGO_ART"
    local info_text="tapectrl v$VERSION\n\nA simple utility to manage LTO tape drives in Linux.\n\nCreated by Gemini."
    show_msgbox "Info" "$logo\n\n$info_text"
}

# --- Main Menu ---
main_menu() {
    while true; do
        run_dialog_capture --clear --backtitle "tapectrl v$VERSION - Tape Device: $TAPE_DEVICE" \
            --title "MAIN MENU" \
            --menu "Select an operation:" \
            $DIALOG_HEIGHT $DIALOG_WIDTH 13 \
            "1" "Write To Tape" \
            "2" "Rewind" \
            "3" "Verify Archive" \
            "4" "Restore From Tape" \
            "5" "Drive Clean" \
            "6" "Erase Tape" \
            "7" "Drive Status" \
            "8" "Offline Tape" \
            "9" "Tape Movement" \
            "10" "Write End Of File" \
            "11" "Retension Tape" \
            "12" "Info" \
            "Exit" "Exit tapectrl"

        local exit_code=$?
        local choice="$DIALOG_RESULT"

        # If dialog exits with an error, it's likely a display problem. Exit gracefully.
        if [ $exit_code -ne 0 ] && [ -z "$choice" ]; then
            echo "Dialog failed to run. Check terminal compatibility." >&2
            break
        fi

        case $choice in
            1) write_to_tape ;;
            2) rewind_tape ;;
            3) verify_archive ;;
            4) restore_from_tape ;;
            5) clean_drive ;;
            6) erase_tape ;;
            7) drive_status ;;
            8) offline_tape ;;
            9) tape_movement_menu ;;
            10) write_eof ;;
            11) retension_tape ;;
            12) show_info ;;
            "Exit" | "") # Exit on "Exit" or if user presses ESC/Cancel
                break
                ;;
        esac
    done
}

# --- Script Start ---
check_deps
clear
main_menu
clear
echo "Exiting tapectrl."
