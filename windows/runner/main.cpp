#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Mode « fenêtre de mise à jour » (kidflix --updating) : petite fenêtre
  // centrée pour le splash de progression, au lieu de la fenêtre app 1280x720.
  bool updating = std::find(command_line_arguments.begin(),
                            command_line_arguments.end(),
                            "--updating") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (updating) {
    // Tailles logiques (Win32Window::Create les met à l'échelle selon le DPI).
    // Assez haut pour le prompt (titre + 3 boutons) comme pour la progression.
    const int width = 480;
    const int height = 250;
    const double scale = ::GetDpiForSystem() / 96.0;
    const int logical_screen_w =
        static_cast<int>(::GetSystemMetrics(SM_CXSCREEN) / scale);
    const int logical_screen_h =
        static_cast<int>(::GetSystemMetrics(SM_CYSCREEN) / scale);
    origin = Win32Window::Point((logical_screen_w - width) / 2,
                                (logical_screen_h - height) / 2);
    size = Win32Window::Size(width, height);
  }
  if (!window.Create(L"Kidflix", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
