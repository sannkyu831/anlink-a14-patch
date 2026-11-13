.method private static createDisplay()Landroid/os/IBinder;
    .registers 3

    # Android 14+ : SurfaceControl virtual display creation is broken,
    # defer to the DisplayManager path (handled in setDisplaySurface)
    sget v0, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v1, 0x22

    if-lt v0, v1, :legacy

    const/4 v0, 0x0

    return-object v0

    :legacy
    invoke-static {}, Link/anl/ScreenEncoder;->createDisplayLegacy()Landroid/os/IBinder;

    move-result-object v0

    return-object v0
.end method
