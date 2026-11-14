.method private static getGetPhysicalDisplayIdsMethod()Ljava/lang/reflect/Method;
    .registers 3

    sget-object v0, Link/anl/wrappers/SurfaceControl;->getPhysicalDisplayIdsMethod:Ljava/lang/reflect/Method;

    if-nez v0, :got_method

    sget-object v0, Link/anl/wrappers/SurfaceControl;->CLASS:Ljava/lang/Class;

    const-string v1, "getPhysicalDisplayIds"

    const/4 v2, 0x0

    new-array v2, v2, [Ljava/lang/Class;

    invoke-virtual {v0, v1, v2}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v0

    sput-object v0, Link/anl/wrappers/SurfaceControl;->getPhysicalDisplayIdsMethod:Ljava/lang/reflect/Method;

    :got_method
    return-object v0
.end method

.method private static getGetPhysicalDisplayTokenMethod()Ljava/lang/reflect/Method;
    .registers 5

    sget-object v0, Link/anl/wrappers/SurfaceControl;->getPhysicalDisplayTokenMethod:Ljava/lang/reflect/Method;

    if-nez v0, :got_method

    sget-object v0, Link/anl/wrappers/SurfaceControl;->CLASS:Ljava/lang/Class;

    const-string v1, "getPhysicalDisplayToken"

    const/4 v2, 0x1

    new-array v2, v2, [Ljava/lang/Class;

    const/4 v3, 0x0

    sget-object v4, Ljava/lang/Long;->TYPE:Ljava/lang/Class;

    aput-object v4, v2, v3

    invoke-virtual {v0, v1, v2}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v0

    sput-object v0, Link/anl/wrappers/SurfaceControl;->getPhysicalDisplayTokenMethod:Ljava/lang/reflect/Method;

    :got_method
    return-object v0
.end method

.method public static getPhysicalDisplayIds()[J
    .registers 4

    const/4 v0, 0x0

    :try_start
    invoke-static {}, Link/anl/wrappers/SurfaceControl;->getGetPhysicalDisplayIdsMethod()Ljava/lang/reflect/Method;

    move-result-object v1

    const/4 v2, 0x0

    new-array v3, v2, [Ljava/lang/Object;

    invoke-virtual {v1, v0, v3}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, [J
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :catch

    return-object v1

    :catch
    move-exception v1

    const-string v2, "Could not get physical display ids"

    invoke-static {v2, v1}, Link/anl/Ln;->e(Ljava/lang/String;Ljava/lang/Throwable;)V

    return-object v0
.end method

.method public static getPhysicalDisplayToken(J)Landroid/os/IBinder;
    .registers 6

    const/4 v0, 0x0

    :try_start
    invoke-static {}, Link/anl/wrappers/SurfaceControl;->getGetPhysicalDisplayTokenMethod()Ljava/lang/reflect/Method;

    move-result-object v1

    const/4 v2, 0x1

    new-array v2, v2, [Ljava/lang/Object;

    const/4 v3, 0x0

    invoke-static {p0, p1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v4

    aput-object v4, v2, v3

    invoke-virtual {v1, v0, v2}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/os/IBinder;
    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :catch

    return-object v1

    :catch
    move-exception v1

    const-string v2, "Could not get physical display token"

    invoke-static {v2, v1}, Link/anl/Ln;->e(Ljava/lang/String;Ljava/lang/Throwable;)V

    return-object v0
.end method

.method public static hasPhysicalDisplayIdsMethod()Z
    .registers 2

    :try_start
    invoke-static {}, Link/anl/wrappers/SurfaceControl;->getGetPhysicalDisplayIdsMethod()Ljava/lang/reflect/Method;
    :try_end
    .catch Ljava/lang/NoSuchMethodException; {:try_start .. :try_end} :catch

    const/4 v0, 0x1

    return v0

    :catch
    move-exception v0

    const/4 v0, 0x0

    return v0
.end method
