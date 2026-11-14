.class public final Link/anl/wrappers/DisplayControl;
.super Ljava/lang/Object;
.source "DisplayControl.java"

# Compatibility wrapper for Android 14+, adapted from scrcpy's
# wrappers/DisplayControl.java (Apache-2.0).

# static fields
.field private static final CLASS:Ljava/lang/Class;

.field private static getPhysicalDisplayIdsMethod:Ljava/lang/reflect/Method;

.field private static getPhysicalDisplayTokenMethod:Ljava/lang/reflect/Method;


# direct methods
.method static constructor <clinit>()V
    .registers 8

    const/4 v0, 0x0

    :try_start
    const-string v1, "com.android.internal.os.ClassLoaderFactory"

    invoke-static {v1}, Ljava/lang/Class;->forName(Ljava/lang/String;)Ljava/lang/Class;

    move-result-object v1

    const-string v2, "createClassLoader"

    const/4 v3, 0x7

    new-array v3, v3, [Ljava/lang/Class;

    const/4 v4, 0x0

    const-class v5, Ljava/lang/String;

    aput-object v5, v3, v4

    const/4 v5, 0x1

    const-class v6, Ljava/lang/String;

    aput-object v6, v3, v5

    const/4 v6, 0x2

    const-class v7, Ljava/lang/String;

    aput-object v7, v3, v6

    const/4 v6, 0x3

    const-class v7, Ljava/lang/ClassLoader;

    aput-object v7, v3, v6

    const/4 v6, 0x4

    sget-object v7, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    aput-object v7, v3, v6

    const/4 v6, 0x5

    sget-object v7, Ljava/lang/Boolean;->TYPE:Ljava/lang/Class;

    aput-object v7, v3, v6

    const/4 v6, 0x6

    const-class v7, Ljava/lang/String;

    aput-object v7, v3, v6

    invoke-virtual {v1, v2, v3}, Ljava/lang/Class;->getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v2

    const-string v1, "SYSTEMSERVERCLASSPATH"

    # Keep the complete classpath from the runtime. Vendor classes such as
    # DeviceControlService may live outside /system/framework/services.jar.
    invoke-static {v1}, Landroid/system/Os;->getenv(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v1

    const/4 v3, 0x7

    new-array v3, v3, [Ljava/lang/Object;

    const/4 v4, 0x0

    aput-object v1, v3, v4

    const/4 v5, 0x1

    const/4 v6, 0x0

    aput-object v6, v3, v5

    const/4 v5, 0x2

    aput-object v6, v3, v5

    invoke-static {}, Ljava/lang/ClassLoader;->getSystemClassLoader()Ljava/lang/ClassLoader;

    move-result-object v5

    const/4 v7, 0x3

    aput-object v5, v3, v7

    const/4 v5, 0x4

    invoke-static {v4}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v7

    aput-object v7, v3, v5

    const/4 v5, 0x5

    const/4 v7, 0x1

    invoke-static {v7}, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;

    move-result-object v7

    aput-object v7, v3, v5

    const/4 v5, 0x6

    aput-object v6, v3, v5

    invoke-virtual {v2, v4, v3}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Ljava/lang/ClassLoader;

    move-object v7, v1

    const-string v2, "com.android.server.display.DisplayControl"

    invoke-virtual {v7, v2}, Ljava/lang/ClassLoader;->loadClass(Ljava/lang/String;)Ljava/lang/Class;

    move-result-object v1

    sput-object v1, Link/anl/wrappers/DisplayControl;->CLASS:Ljava/lang/Class;

    # libandroid_servers' JNI_OnLoad registers DeviceControlService from
    # service-flyme.jar. Resolve it through the same class loader before
    # loading the native library.
    const-string v2, "com.android.server.DeviceControlService"

    invoke-virtual {v7, v2}, Ljava/lang/ClassLoader;->loadClass(Ljava/lang/String;)Ljava/lang/Class;

    move-result-object v1

    const-class v2, Ljava/lang/Runtime;

    const-string v3, "loadLibrary0"

    const/4 v4, 0x2

    new-array v4, v4, [Ljava/lang/Class;

    const/4 v5, 0x0

    const-class v6, Ljava/lang/Class;

    aput-object v6, v4, v5

    const/4 v5, 0x1

    const-class v6, Ljava/lang/String;

    aput-object v6, v4, v5

    invoke-virtual {v2, v3, v4}, Ljava/lang/Class;->getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v2

    const/4 v3, 0x1

    invoke-virtual {v2, v3}, Ljava/lang/reflect/Method;->setAccessible(Z)V

    invoke-static {}, Ljava/lang/Runtime;->getRuntime()Ljava/lang/Runtime;

    move-result-object v3

    const/4 v4, 0x2

    new-array v4, v4, [Ljava/lang/Object;

    const/4 v5, 0x0

    aput-object v1, v4, v5

    const/4 v5, 0x1

    const-string v6, "android_servers"

    aput-object v6, v4, v5

    invoke-virtual {v2, v3, v4}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch

    const-string v0, "anlink-power: DisplayControl initialized"

    invoke-static {v0}, Link/anl/Ln;->i(Ljava/lang/String;)V

    return-void

    :catch
    move-exception v1

    const/4 v0, 0x0

    sput-object v0, Link/anl/wrappers/DisplayControl;->CLASS:Ljava/lang/Class;

    const-string v2, "Could not initialize DisplayControl"

    invoke-static {v2, v1}, Link/anl/Ln;->e(Ljava/lang/String;Ljava/lang/Throwable;)V

    return-void
.end method

.method private constructor <init>()V
    .registers 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method private static getGetPhysicalDisplayIdsMethod()Ljava/lang/reflect/Method;
    .registers 4

    sget-object v0, Link/anl/wrappers/DisplayControl;->getPhysicalDisplayIdsMethod:Ljava/lang/reflect/Method;

    if-nez v0, :got_method

    sget-object v0, Link/anl/wrappers/DisplayControl;->CLASS:Ljava/lang/Class;

    const-string v1, "getPhysicalDisplayIds"

    const/4 v2, 0x0

    new-array v3, v2, [Ljava/lang/Class;

    invoke-virtual {v0, v1, v3}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v0

    sput-object v0, Link/anl/wrappers/DisplayControl;->getPhysicalDisplayIdsMethod:Ljava/lang/reflect/Method;

    :got_method
    return-object v0
.end method

.method private static getGetPhysicalDisplayTokenMethod()Ljava/lang/reflect/Method;
    .registers 5

    sget-object v0, Link/anl/wrappers/DisplayControl;->getPhysicalDisplayTokenMethod:Ljava/lang/reflect/Method;

    if-nez v0, :got_method

    sget-object v0, Link/anl/wrappers/DisplayControl;->CLASS:Ljava/lang/Class;

    const-string v1, "getPhysicalDisplayToken"

    const/4 v2, 0x1

    new-array v2, v2, [Ljava/lang/Class;

    const/4 v3, 0x0

    sget-object v4, Ljava/lang/Long;->TYPE:Ljava/lang/Class;

    aput-object v4, v2, v3

    invoke-virtual {v0, v1, v2}, Ljava/lang/Class;->getMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v0

    sput-object v0, Link/anl/wrappers/DisplayControl;->getPhysicalDisplayTokenMethod:Ljava/lang/reflect/Method;

    :got_method
    return-object v0
.end method


# virtual methods
.method public static getPhysicalDisplayIds()[J
    .registers 4

    const/4 v0, 0x0

    :try_start
    invoke-static {}, Link/anl/wrappers/DisplayControl;->getGetPhysicalDisplayIdsMethod()Ljava/lang/reflect/Method;

    move-result-object v1

    const/4 v2, 0x0

    new-array v3, v2, [Ljava/lang/Object;

    invoke-virtual {v1, v0, v3}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, [J
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch

    const-string v2, "anlink-power: DisplayControl.getPhysicalDisplayIds returned"

    invoke-static {v2}, Link/anl/Ln;->i(Ljava/lang/String;)V

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
    invoke-static {}, Link/anl/wrappers/DisplayControl;->getGetPhysicalDisplayTokenMethod()Ljava/lang/reflect/Method;

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
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch

    return-object v1

    :catch
    move-exception v1

    const-string v2, "Could not get physical display token"

    invoke-static {v2, v1}, Link/anl/Ln;->e(Ljava/lang/String;Ljava/lang/Throwable;)V

    return-object v0
.end method
