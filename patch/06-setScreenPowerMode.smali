.method public static setScreenPowerMode(I)Z
    .registers 11

    # Android 14 moved the physical display APIs to DisplayControl.
    # Keep the original single-display path as a fallback for vendor ROMs.
    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v1, 0x22

    if-lt v0, v1, :legacy

    const-string v0, "anlink-power: setScreenPowerMode on Android 14+"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    # Prefer SurfaceControl when the ROM exposes the physical-display methods.
    # Android 14 moved them to DisplayControl; later releases may add them back.
    const/4 v8, 0x0

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->hasPhysicalDisplayIdsMethod()Z

    move-result v8

    if-eqz v8, :use_display_control

    const-string v0, "anlink-power: using SurfaceControl physical displays"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->getPhysicalDisplayIds()[J

    move-result-object v0

    goto :ids_ready

    :use_display_control
    const-string v0, "anlink-power: using DisplayControl physical displays"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    invoke-static {}, Link/anl/wrappers/DisplayControl;->getPhysicalDisplayIds()[J

    move-result-object v0

    :ids_ready
    if-eqz v0, :legacy

    array-length v1, v0

    if-eqz v1, :legacy

    move-object v9, v0

    const-string v0, "anlink-power: physical display list found"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    const/4 v2, 0x1

    const/4 v3, 0x0

    :loop
    if-ge v3, v1, :done

    aget-wide v4, v9, v3

    if-eqz v8, :token_display_control

    invoke-static {v4, v5}, Link/anl/wrappers/SurfaceControl;->getPhysicalDisplayToken(J)Landroid/os/IBinder;

    move-result-object v6

    goto :token_ready

    :token_display_control
    invoke-static {v4, v5}, Link/anl/wrappers/DisplayControl;->getPhysicalDisplayToken(J)Landroid/os/IBinder;

    move-result-object v6

    :token_ready
    invoke-static {v6, p0}, Link/anl/wrappers/SurfaceControl;->setDisplayPowerMode(Landroid/os/IBinder;I)Z

    move-result v7

    and-int/2addr v2, v7

    add-int/lit8 v3, v3, 0x1

    goto :loop

    :done
    if-eqz v2, :done_failed

    const-string v0, "anlink-power: display power applied"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    goto :done_return

    :done_failed
    const-string v0, "anlink-power: one or more display power calls failed"

    invoke-static {v0}, Link/anl/Ln;->e(Ljava/lang/String;)V

    :done_return
    return v2

    :legacy
    const-string v0, "anlink-power: falling back to built-in display"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->getBuiltInDisplay()Landroid/os/IBinder;

    move-result-object v0

    if-nez v0, :no_display

    const-string v1, "Could not get built-in display"

    invoke-static {v1}, Link/anl/Ln;->e(Ljava/lang/String;)V

    const/4 v0, 0x0

    return v0

    :no_display
    invoke-static {v0, p0}, Link/anl/wrappers/SurfaceControl;->setDisplayPowerMode(Landroid/os/IBinder;I)Z

    move-result v0

    return v0
.end method
