using System.Runtime.InteropServices;

namespace GoNetworkScanner.Bridge;

/// <summary>
/// P/Invoke declarations for the Go libipscan shared library.
/// All exported functions use Cdecl calling convention and ANSI strings.
/// </summary>
internal static class NativeMethods
{
    private const string DllName = "libipscan";

    // Callback delegate types matching the C typedefs:
    //   typedef void (*ResultCallback)(const char* result_json, void* context);
    //   typedef void (*ProgressCallback)(const char* progress_json, void* context);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    internal delegate void ResultCallbackDelegate(IntPtr jsonPtr, IntPtr ctx);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    internal delegate void ProgressCallbackDelegate(IntPtr jsonPtr, IntPtr ctx);

    // Instance lifecycle

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern void ipscan_set_config_dir(string dir);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern int ipscan_new(string? configJson);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void ipscan_free(int handle);

    // State

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr ipscan_get_state(int handle);

    // Configuration

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr ipscan_get_config(int handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern int ipscan_set_config(int handle, string configJson);

    // Callbacks

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void ipscan_set_result_callback(
        int handle, ResultCallbackDelegate cb, IntPtr ctx);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void ipscan_set_progress_callback(
        int handle, ProgressCallbackDelegate cb, IntPtr ctx);

    // Scanning

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern int ipscan_start_scan(int handle, string feederJson);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int ipscan_stop_scan(int handle);

    // Results

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int ipscan_get_results_count(int handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr ipscan_get_result(int handle, int index);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr ipscan_get_stats(int handle);

    // Fetchers

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr ipscan_get_available_fetchers(int handle);

    // Export

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern int ipscan_export(int handle, string format, string path);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern int ipscan_export_filtered(int handle, string format, string path, string filter);

    // Comments (per-IP persistent annotations)

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern void ipscan_set_comment(int handle, string ip, string comment);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern IntPtr ipscan_get_comment(int handle, string ip);

    // Result operations

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern void ipscan_delete_result(int handle, string ip);

    // Favorites (named scan targets)

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    internal static extern void ipscan_save_favorite(int handle, string name, string feederArgs);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern IntPtr ipscan_get_favorites(int handle);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void ipscan_delete_favorite(int handle, int index);

    // Memory management — must call after reading any returned string

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void ipscan_free_string(IntPtr ptr);

    /// <summary>
    /// Read a C string returned by Go, convert to managed string, and free the native memory.
    /// </summary>
    internal static string? ReadAndFree(IntPtr ptr)
    {
        if (ptr == IntPtr.Zero) return null;
        try
        {
            return Marshal.PtrToStringAnsi(ptr);
        }
        finally
        {
            ipscan_free_string(ptr);
        }
    }
}
