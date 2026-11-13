.method private static setDisplaySurface(Landroid/os/IBinder;Landroid/view/Surface;ILandroid/graphics/Rect;Landroid/graphics/Rect;I)V
    .registers 7

    if-nez p0, :legacy

    :try_start_0
    invoke-static {p1, p4}, Link/anl/ScreenEncoder;->createVirtualDisplay(Landroid/view/Surface;Landroid/graphics/Rect;)Landroid/hardware/display/VirtualDisplay;

    move-result-object v0

    sput-object v0, Link/anl/ScreenEncoder;->virtualDisplay:Landroid/hardware/display/VirtualDisplay;

    return-void
    :try_end_0
    .catchall {:try_start_0 .. :try_end_0} :catchall_0

    :catchall_0
    move-exception v0

    invoke-static {}, Link/anl/ScreenEncoder;->createDisplayLegacy()Landroid/os/IBinder;

    move-result-object p0

    :legacy
    invoke-static {}, Link/anl/wrappers/SurfaceControl;->openTransaction()V

    :try_start_3
    invoke-static {p0, p1}, Link/anl/wrappers/SurfaceControl;->setDisplaySurface(Landroid/os/IBinder;Landroid/view/Surface;)V

    invoke-static {p0, p2, p3, p4}, Link/anl/wrappers/SurfaceControl;->setDisplayProjection(Landroid/os/IBinder;ILandroid/graphics/Rect;Landroid/graphics/Rect;)V

    invoke-static {p0, p5}, Link/anl/wrappers/SurfaceControl;->setDisplayLayerStack(Landroid/os/IBinder;I)V
    :try_end_c
    .catchall {:try_start_3 .. :try_end_c} :catchall_11

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->closeTransaction()V

    nop

    return-void

    :catchall_11
    move-exception p0

    invoke-static {}, Link/anl/wrappers/SurfaceControl;->closeTransaction()V

    throw p0
.end method
