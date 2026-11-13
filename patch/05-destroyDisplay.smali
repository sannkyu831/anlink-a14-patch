.method private static destroyDisplay(Landroid/os/IBinder;)V
    .registers 2

    if-nez p0, :legacy

    sget-object v0, Link/anl/ScreenEncoder;->virtualDisplay:Landroid/hardware/display/VirtualDisplay;

    if-eqz v0, :done

    invoke-virtual {v0}, Landroid/hardware/display/VirtualDisplay;->release()V

    const/4 v0, 0x0

    sput-object v0, Link/anl/ScreenEncoder;->virtualDisplay:Landroid/hardware/display/VirtualDisplay;

    :done
    return-void

    :legacy
    invoke-static {p0}, Link/anl/wrappers/SurfaceControl;->destroyDisplay(Landroid/os/IBinder;)V

    return-void
.end method
