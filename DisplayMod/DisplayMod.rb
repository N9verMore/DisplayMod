#==============================================================================
# ■ DisplayMod — настройки отображения для BLACK SOULS II (RPG Maker VX Ace)
#------------------------------------------------------------------------------
#  * Режимы: оконный / безрамочный полноэкранный / полноэкранный (со сменой
#    разрешения монитора).
#  * Масштаб: авто (растянуть на весь экран), пропорционально (чёрные полосы),
#    целочисленный x1..xN (чёткие пиксели, чёрные полосы).
#  * Разрешение: размер окна / разрешение монитора.
#  * F5 — открыть меню настроек в любой момент, Alt+Enter — переключение
#    оконный <-> полноэкранный (вместо штатного 640x480).
#  Настройки сохраняются в DisplaySettings.ini в папке игры.
#==============================================================================

module DisplayMod
  VERSION     = '1.1'
  CONFIG_FILE = 'DisplaySettings.ini'
  LOG_FILE    = 'DisplayMod/log.txt'
  DEBUG       = File.directory?('DisplayMod') && File.exist?('DisplayMod/debug')
  MENU_KEY    = 0x74  # VK_F5

  MODE_WINDOWED   = 0
  MODE_BORDERLESS = 1
  MODE_FULLSCREEN = 2

  # Внутреннее разрешение игры (у BLACK SOULS II — 640x480, задаётся скриптом
  # EX WINDOW). Берём у движка, чтобы мод не зависел от версии игры.
  def self.base_w; Graphics.width; end
  def self.base_h; Graphics.height; end

  #--------------------------------------------------------------------------
  # Тексты (русский, если игра русифицирована, иначе английский)
  #--------------------------------------------------------------------------
  TEXT = {
    :ru => {
      :modes => ['Оконный', 'Безрамочный', 'Полноэкранный'],
      :title_cmd => 'Настройки экрана', :header => 'Настройки экрана',
      :mode => 'Режим экрана', :res => 'Разрешение', :scale => 'Масштаб',
      :apply => 'Применить', :close => 'Закрыть',
      :stretch => 'Авто (растянуть)', :fit => 'Пропорционально',
      :desktop => 'рабочий стол',
      :applied => 'Настройки применены и сохранены.',
      :failed => 'Не удалось сменить разрешение монитора — включён безрамочный режим.',
      :hint_mode => 'Оконный — обычное окно. Безрамочный — без рамки на весь экран (рекомендуется). Полноэкранный — то же, но со сменой разрешения монитора.',
      :hint_res => 'Оконный: размер окна. Полноэкранный: разрешение монитора. В безрамочном режиме используется разрешение рабочего стола.',
      :hint_scale => 'Авто — растянуть на весь экран. Пропорционально — без искажений, по краям чёрные полосы. x1, x2... — чёткие пиксели (целое увеличение).',
      :hint_apply => 'Применить и сохранить выбранные настройки.',
      :hint_close => 'Закрыть меню. F5 — открыть это меню в любой момент, Alt+Enter — оконный / полноэкранный.',
    },
    :en => {
      :modes => ['Windowed', 'Borderless', 'Fullscreen'],
      :title_cmd => 'Display', :header => 'Display Settings',
      :mode => 'Display mode', :res => 'Resolution', :scale => 'Scaling',
      :apply => 'Apply', :close => 'Close',
      :stretch => 'Auto (stretch)', :fit => 'Keep aspect',
      :desktop => 'desktop',
      :applied => 'Settings applied and saved.',
      :failed => 'Could not change the monitor resolution, switched to borderless.',
      :hint_mode => 'Windowed - a normal window. Borderless - fills the screen without a frame (recommended). Fullscreen - same, but changes the monitor resolution.',
      :hint_res => 'Windowed: window size. Fullscreen: monitor resolution. Borderless always uses the desktop resolution.',
      :hint_scale => 'Auto - stretch to the whole screen. Keep aspect - no distortion, black bars. x1, x2... - sharp pixels (integer scaling).',
      :hint_apply => 'Apply and save the selected settings.',
      :hint_close => 'Close the menu. F5 opens this menu at any time, Alt+Enter toggles windowed / fullscreen.',
    },
  }

  def self.language
    return @language if @language
    return :ru unless $data_system # данные игры ещё не загружены
    sample = [Vocab::new_game, Vocab::continue, Vocab::shutdown].join rescue ''
    @language = sample =~ /[Ѐ-ӿ]/ ? :ru : :en
  end

  def self.t(key)
    TEXT[language][key]
  end

  #--------------------------------------------------------------------------
  # WinAPI
  #--------------------------------------------------------------------------
  module API
    def self.f(dll, name, imp, exp = 'i')
      Win32API.new(dll, name, imp, exp)
    end
    GetCurrentProcessId      = f('kernel32', 'GetCurrentProcessId', '')
    GetModuleHandle          = f('kernel32', 'GetModuleHandleA', 'p')
    GetProcAddress           = f('kernel32', 'GetProcAddress', 'ip')
    FindWindowEx             = f('user32', 'FindWindowExA', 'iipp')
    GetWindowThreadProcessId = f('user32', 'GetWindowThreadProcessId', 'ip')
    GetWindowLong            = f('user32', 'GetWindowLongA', 'ii')
    SetWindowLong            = f('user32', 'SetWindowLongA', 'iii')
    SetWindowPos             = f('user32', 'SetWindowPos', 'iiiiiii')
    ShowWindow               = f('user32', 'ShowWindow', 'ii')
    IsWindowVisible          = f('user32', 'IsWindowVisible', 'i')
    IsIconic                 = f('user32', 'IsIconic', 'i')
    GetWindow                = f('user32', 'GetWindow', 'ii')
    GetWindowRect            = f('user32', 'GetWindowRect', 'ip')
    GetForegroundWindow      = f('user32', 'GetForegroundWindow', '')
    GetAsyncKeyState         = f('user32', 'GetAsyncKeyState', 'i')
    MonitorFromWindow        = f('user32', 'MonitorFromWindow', 'ii')
    GetMonitorInfo           = f('user32', 'GetMonitorInfoA', 'ip')
    AdjustWindowRectEx       = f('user32', 'AdjustWindowRectEx', 'piii')
    RegisterClassEx          = f('user32', 'RegisterClassExA', 'p')
    CreateWindowEx           = f('user32', 'CreateWindowExA', 'ippiiiiiiiii')
    LoadCursor               = f('user32', 'LoadCursorA', 'ii')
    RegisterHotKey           = f('user32', 'RegisterHotKey', 'iiii')
    UnregisterHotKey         = f('user32', 'UnregisterHotKey', 'ii')
    KeybdEvent               = f('user32', 'keybd_event', 'iiii', 'v')
    EnumDisplaySettings      = f('user32', 'EnumDisplaySettingsA', 'pip')
    ChangeDisplaySettingsEx  = f('user32', 'ChangeDisplaySettingsExA', 'ppiii')
    PeekMessage              = f('user32', 'PeekMessageA', 'piiii')
    DispatchMessage          = f('user32', 'DispatchMessageA', 'p')
    GetStockObject           = f('gdi32', 'GetStockObject', 'i')
  end

  GWL_STYLE   = -16
  GWL_EXSTYLE = -20
  WS_POPUP        = 0x80000000
  WS_VISIBLE      = 0x10000000
  WS_CLIPSIBLINGS = 0x04000000
  WS_CAPTION      = 0x00C00000
  WS_SYSMENU      = 0x00080000
  WS_MINIMIZEBOX  = 0x00020000
  WS_EX_TOPMOST    = 0x00000008
  WS_EX_TOOLWINDOW = 0x00000080
  WS_EX_NOACTIVATE = 0x08000000
  STYLE_WINDOWED   = WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_VISIBLE | WS_CLIPSIBLINGS
  STYLE_POPUP      = WS_POPUP | WS_VISIBLE | WS_CLIPSIBLINGS
  SWP_NOSIZE = 0x1; SWP_NOMOVE = 0x2; SWP_NOZORDER = 0x4; SWP_NOACTIVATE = 0x10
  SWP_FRAMECHANGED = 0x20; SWP_SHOWWINDOW = 0x40; SWP_NOOWNERZORDER = 0x200
  HWND_NOTOPMOST = -2
  CDS_FULLSCREEN = 0x4
  HOTKEY_ID = 0x4D44

  class << self
    attr_reader :hwnd, :mode, :scale, :win_res, :fs_res
  end

  #--------------------------------------------------------------------------
  # Лог (только если существует файл DisplayMod/debug)
  #--------------------------------------------------------------------------
  def self.log(msg)
    return unless DEBUG
    File.open(LOG_FILE, 'a') { |f| f.puts("#{Time.now.strftime('%H:%M:%S.%L')} #{msg}") }
  rescue
  end

  def self.safe
    yield
  rescue Exception => e
    raise if e.is_a?(SystemExit) || (defined?(RGSSReset) && e.is_a?(RGSSReset))
    log("ERROR #{e.class}: #{e.message}\n  #{(e.backtrace || [])[0, 6].join("\n  ")}")
    nil
  end

  #--------------------------------------------------------------------------
  # Поиск окна игры
  #--------------------------------------------------------------------------
  def self.find_game_window
    pid = API::GetCurrentProcessId.call
    h = 0
    loop do
      h = API::FindWindowEx.call(0, h, 'RGSS Player', 0)
      return 0 if h == 0
      buf = [0].pack('L')
      API::GetWindowThreadProcessId.call(h, buf)
      return h if buf.unpack('L')[0] == pid
    end
  end

  def self.key_down?(vk)
    API::GetAsyncKeyState.call(vk) & 0x8000 != 0
  end

  def self.foreground?
    API::GetForegroundWindow.call == @hwnd
  end

  #--------------------------------------------------------------------------
  # Монитор: {:x,:y,:w,:h (весь монитор), :wx,:wy,:ww,:wh (рабочая область), :device}
  #--------------------------------------------------------------------------
  def self.monitor_info
    hmon = API::MonitorFromWindow.call(@hwnd, 2) # MONITOR_DEFAULTTONEAREST
    buf = [72].pack('L') + "\0" * 68
    API::GetMonitorInfo.call(hmon, buf)
    v = buf.unpack('Ll4l4LZ32')
    { :x => v[1], :y => v[2], :w => v[3] - v[1], :h => v[4] - v[2],
      :wx => v[5], :wy => v[6], :ww => v[7] - v[5], :wh => v[8] - v[6],
      :device => v[10] }
  end

  #--------------------------------------------------------------------------
  # Видеорежимы монитора
  #--------------------------------------------------------------------------
  DEVMODE_SIZE = 156

  def self.new_devmode
    dm = "\0" * (DEVMODE_SIZE + 512)
    dm[36, 2] = [DEVMODE_SIZE].pack('S')
    dm
  end

  # { [w, h] => devmode с максимальной частотой }
  def self.display_modes(device)
    modes = {}
    i = 0
    loop do
      dm = new_devmode
      break if API::EnumDisplaySettings.call(device, i, dm) == 0
      i += 1
      bpp, w, h = dm[104, 12].unpack('L3')
      freq = dm[120, 4].unpack('L')[0]
      next if bpp < 32 || w < base_w || h < base_h
      old = modes[[w, h]]
      modes[[w, h]] = [freq, dm] if old.nil? || freq > old[0]
      break if i > 2000
    end
    modes
  end

  # Разрешение монитора в реестре (рабочего стола), даже если сейчас сменено
  def self.desktop_resolution(device)
    dm = new_devmode
    if API::EnumDisplaySettings.call(device, -2, dm) != 0 # ENUM_REGISTRY_SETTINGS
      w, h = dm[108, 8].unpack('L2')
      return [w, h] if w > 0 && h > 0
    end
    m = monitor_info
    [m[:w], m[:h]]
  end

  def self.change_display_mode(device, w, h)
    entry = display_modes(device)[[w, h]]
    return false unless entry
    r = API::ChangeDisplaySettingsEx.call(device, entry[1], 0, CDS_FULLSCREEN, 0)
    log("ChangeDisplaySettingsEx #{device} #{w}x#{h}@#{entry[0]} => #{r}")
    if r == 0
      @changed_device = device
      @changed_res = [w, h]
      @need_reset = true
      true
    else
      false
    end
  end

  def self.restore_display_mode
    return unless @changed_device
    r = API::ChangeDisplaySettingsEx.call(@changed_device, 0, 0, 0, 0)
    log("restore display mode #{@changed_device} => #{r}")
    @changed_device = nil
    @changed_res = nil
    @need_reset = true
  end

  # После смены видеорежима движок теряет Direct3D-устройство и перестаёт
  # растягивать картинку (рисует 1:1 в углу). Смена внутреннего размера
  # туда-обратно заставляет RGSS полностью пересоздать буфер.
  def self.reset_device
    return if @exiting
    w, h = Graphics.width, Graphics.height
    Graphics.resize_screen(w - 32, h - 32)
    3.times { @orig_update.call }
    Graphics.resize_screen(w, h)
    3.times { @orig_update.call }
  rescue Exception => e
    log("reset_device: #{e.message}")
  end

  #--------------------------------------------------------------------------
  # Списки разрешений
  #--------------------------------------------------------------------------
  WINDOW_FACTORS = [1, 1.25, 1.5, 1.6, 1.8, 2, 2.25, 2.5, 3, 3.5, 4, 4.5]

  def self.window_frame_size
    r = [0, 0, 0, 0].pack('l4')
    API::AdjustWindowRectEx.call(r, STYLE_WINDOWED, 0, 0)
    l, t, rr, b = r.unpack('l4')
    [rr - l, b - t]
  end

  def self.window_resolutions
    m = monitor_info
    fw, fh = window_frame_size
    presets = WINDOW_FACTORS.map { |f| [(base_w * f).round, (base_h * f).round] }
    list = presets + display_modes(m[:device]).keys
    list = list.uniq.select { |w, h| w + fw <= m[:ww] && h + fh <= m[:wh] }
    list = [[base_w, base_h]] if list.empty?
    list.sort
  end

  def self.fullscreen_resolutions
    m = monitor_info
    list = display_modes(m[:device]).keys.sort
    list = [desktop_resolution(m[:device])] if list.empty?
    list
  end

  #--------------------------------------------------------------------------
  # Масштаб: 'stretch' | 'fit' | 'x1'.. — размер картинки внутри области
  #--------------------------------------------------------------------------
  def self.max_integer_scale(aw, ah)
    [[aw / base_w, ah / base_h].min, 1].max
  end

  def self.content_size(aw, ah, scale)
    case scale
    when 'stretch'
      [aw, ah]
    when /^x(\d+)$/
      n = [$1.to_i, max_integer_scale(aw, ah)].min
      if base_w * n > aw || base_h * n > ah
        content_size(aw, ah, 'fit')
      else
        [base_w * n, base_h * n]
      end
    else # 'fit'
      s = [aw.to_f / base_w, ah.to_f / base_h].min
      w = (base_w * s).round
      h = (base_h * s).round
      [[w, aw].min, [h, ah].min]
    end
  end

  # Область, в которую вписывается картинка для данного режима
  def self.target_area(mode, win_res, fs_res)
    m = monitor_info
    case mode
    when MODE_WINDOWED   then win_res
    when MODE_FULLSCREEN then fs_res
    else desktop_resolution(m[:device])
    end
  end

  def self.scale_options(aw, ah)
    ['stretch', 'fit'] + (1..max_integer_scale(aw, ah)).map { |n| "x#{n}" }
  end

  #--------------------------------------------------------------------------
  # Фоновое (чёрное) окно для полос
  #--------------------------------------------------------------------------
  BG_CLASS = "DisplayModBlackBg\0"

  def self.create_bg_window
    return @bg if @bg && @bg != 0
    hinst = API::GetModuleHandle.call(0)
    user32 = API::GetModuleHandle.call('user32')
    wndproc = API::GetProcAddress.call(user32, 'DefWindowProcA')
    brush = API::GetStockObject.call(4) # BLACK_BRUSH
    cursor = API::LoadCursor.call(0, 32512) # IDC_ARROW
    name_ptr = [BG_CLASS].pack('p').unpack('L')[0]
    wc = [48, 3, wndproc, 0, 0, hinst, 0, cursor, brush, 0, name_ptr, 0].map { |v| v & 0xFFFFFFFF }.pack('L12')
    atom = API::RegisterClassEx.call(wc)
    @bg = API::CreateWindowEx.call(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, BG_CLASS,
      "BLACK SOULS II background\0", WS_POPUP | WS_CLIPSIBLINGS, 0, 0, 1, 1, 0, 0, hinst, 0)
    log("bg window atom=#{atom} hwnd=#{@bg}")
    @bg
  end

  def self.show_bg(x, y, w, h)
    bg = create_bg_window
    return if bg == 0
    @bg_place = [x, y, w, h]
    # Сразу под окном игры
    API::SetWindowPos.call(bg, @hwnd, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_NOOWNERZORDER)
    @bg_visible = true
  end

  def self.hide_bg
    API::ShowWindow.call(@bg, 0) if @bg && @bg != 0
    @bg_visible = false
  end

  # Движок обрабатывает сообщения только своего окна — фоновое обслуживаем сами
  def self.pump_bg
    return unless @bg && @bg != 0
    msg = [0].pack("L") * 7
    8.times do
      break if API::PeekMessage.call(msg, @bg, 0, 0, 1) == 0 # PM_REMOVE
      if msg[4, 4].unpack('L')[0] == 0x0312 # WM_HOTKEY
        @hotkey_hit = true
      else
        API::DispatchMessage.call(msg)
      end
    end
  end

  def self.keep_bg_below
    pump_bg
    return unless @bg_visible
    if API::GetWindow.call(@hwnd, 2) != @bg # GW_HWNDNEXT
      API::SetWindowPos.call(@bg, @hwnd, 0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER)
    end
  end

  #--------------------------------------------------------------------------
  # Штатный полноэкранный режим RGSS (640x480)
  #--------------------------------------------------------------------------
  def self.engine_fullscreen?
    style = API::GetWindowLong.call(@hwnd, GWL_STYLE) & 0xFFFFFFFF
    ex = API::GetWindowLong.call(@hwnd, GWL_EXSTYLE) & 0xFFFFFFFF
    style & WS_CAPTION == 0 && ex & WS_EX_TOPMOST != 0 && !@applied_once
  end

  # Выход из штатного полноэкранного режима (если игра так запустилась)
  def self.leave_engine_fullscreen
    return unless engine_fullscreen?
    log('engine started in its own fullscreen, toggling back')
    # Эмулируем Alt+Enter (только если окно игры активно)
    return log('not foreground, cannot toggle') unless foreground?
    API::UnregisterHotKey.call(@hotkey_hwnd, HOTKEY_ID) if @hotkey
    API::KeybdEvent.call(0x12, 0x38, 0, 0)
    API::KeybdEvent.call(0x0D, 0x1C, 0, 0)
    API::KeybdEvent.call(0x0D, 0x1C, 2, 0)
    API::KeybdEvent.call(0x12, 0x38, 2, 0)
    60.times { @orig_update.call; break unless engine_fullscreen? }
    API::RegisterHotKey.call(@hotkey_hwnd, HOTKEY_ID, 0x4001, 0x0D) if @hotkey
    log("after keybd toggle: fullscreen=#{engine_fullscreen?}")
  end

  #--------------------------------------------------------------------------
  # Применение настроек
  #--------------------------------------------------------------------------
  def self.set_styles(style)
    API::SetWindowLong.call(@hwnd, GWL_STYLE, style)
    ex = API::GetWindowLong.call(@hwnd, GWL_EXSTYLE) & 0xFFFFFFFF
    API::SetWindowLong.call(@hwnd, GWL_EXSTYLE, ex & ~WS_EX_TOPMOST)
  end

  def self.apply(mode = @mode, win_res = @win_res, fs_res = @fs_res, scale = @scale)
    return false if @hwnd == 0
    ok = true
    @mode, @win_res, @fs_res, @scale = mode, win_res, fs_res, scale
    m = monitor_info
    # Смена разрешения монитора
    if mode == MODE_FULLSCREEN
      if @changed_res != fs_res
        restore_display_mode
        m = monitor_info
        if [m[:w], m[:h]] != fs_res
          unless change_display_mode(m[:device], fs_res[0], fs_res[1])
            ok = false
            @mode = mode = MODE_BORDERLESS
          end
        end
      end
    else
      restore_display_mode
    end
    m = monitor_info
    if mode == MODE_WINDOWED
      hide_bg
      cw, ch = content_size(win_res[0], win_res[1], scale)
      set_styles(STYLE_WINDOWED)
      r = [0, 0, cw, ch].pack('l4')
      API::AdjustWindowRectEx.call(r, STYLE_WINDOWED, 0, 0)
      l, t, rr, b = r.unpack('l4')
      ww, wh = rr - l, b - t
      x = m[:wx] + [(m[:ww] - ww) / 2, 0].max
      y = m[:wy] + [(m[:wh] - wh) / 2, 0].max
      @place = [x, y, ww, wh]
      API::SetWindowPos.call(@hwnd, HWND_NOTOPMOST, x, y, ww, wh, SWP_FRAMECHANGED | SWP_SHOWWINDOW)
    else
      aw, ah = m[:w], m[:h]
      cw, ch = content_size(aw, ah, scale)
      x = m[:x] + (aw - cw) / 2
      y = m[:y] + (ah - ch) / 2
      set_styles(STYLE_POPUP)
      @place = [x, y, cw, ch]
      API::SetWindowPos.call(@hwnd, HWND_NOTOPMOST, x, y, cw, ch, SWP_FRAMECHANGED | SWP_SHOWWINDOW)
      if cw < aw || ch < ah
        show_bg(m[:x], m[:y], aw, ah)
      else
        hide_bg
      end
    end
    if @need_reset
      @need_reset = false
      reset_device
      # resize_screen может вернуть окну размер 640x480 — ставим заново
      API::SetWindowPos.call(@hwnd, HWND_NOTOPMOST, @place[0], @place[1], @place[2], @place[3], SWP_FRAMECHANGED | SWP_SHOWWINDOW)
      show_bg(*@bg_place) if @bg_visible
    end
    @applied_once = true
    @last_fullscreen_mode = mode if mode != MODE_WINDOWED
    log("apply mode=#{mode} win=#{win_res.inspect} fs=#{fs_res.inspect} scale=#{scale} monitor=#{m.inspect} content=#{cw}x#{ch}")
    ok
  end

  #--------------------------------------------------------------------------
  # Настройки: загрузка / сохранение
  #--------------------------------------------------------------------------
  def self.parse_res(s)
    return nil unless s =~ /^\s*(\d+)\s*x\s*(\d+)\s*$/i
    [$1.to_i, $2.to_i]
  end

  def self.load_settings
    m = monitor_info
    desk = desktop_resolution(m[:device])
    @mode = MODE_BORDERLESS
    @scale = 'fit'
    @fs_res = desk
    wl = window_resolutions
    @win_res = wl.select { |w, h| w * base_h == h * base_w }.last || wl.last
    @last_fullscreen_mode = MODE_BORDERLESS
    return unless File.exist?(CONFIG_FILE)
    File.open(CONFIG_FILE, 'r') do |f|
      f.each_line do |line|
        k, v = line.strip.split('=', 2)
        next unless v
        v = v.strip
        case k.strip.downcase
        when 'mode'
          @mode = v.to_i if (0..2).include?(v.to_i)
        when 'window'
          r = parse_res(v); @win_res = r if r
        when 'fullscreen'
          r = parse_res(v); @fs_res = r if r
        when 'scale'
          @scale = v if v =~ /^(stretch|fit|x\d+)$/
        when 'last_fullscreen_mode'
          @last_fullscreen_mode = v.to_i if [1, 2].include?(v.to_i)
        when 'language'
          if %w(ru en).include?(v.downcase)
            @language_setting = v.downcase
            @language = v.downcase.to_sym
          end
        end
      end
    end
  rescue Exception => e
    log("load_settings: #{e.message}")
  end

  def self.save_settings
    File.open(CONFIG_FILE, 'w') do |f|
      f.puts '; DisplayMod settings (in-game menu: F5)'
      f.puts '; mode: 0 = windowed, 1 = borderless, 2 = fullscreen'
      f.puts '; scale: stretch, fit, x1, x2, ...'
      f.puts '; language: auto, ru, en'
      f.puts "mode=#{@mode}"
      f.puts "window=#{@win_res[0]}x#{@win_res[1]}"
      f.puts "fullscreen=#{@fs_res[0]}x#{@fs_res[1]}"
      f.puts "scale=#{@scale}"
      f.puts "last_fullscreen_mode=#{@last_fullscreen_mode || 1}"
      f.puts "language=#{@language_setting || 'auto'}"
    end
  rescue Exception => e
    log("save_settings: #{e.message}")
  end

  #--------------------------------------------------------------------------
  # Инициализация и покадровое обновление
  #--------------------------------------------------------------------------
  def self.setup(orig_update)
    return if @ready # повторный запуск скриптов (F12)
    @orig_update = orig_update
    @hwnd = find_game_window
    log("setup v#{VERSION} hwnd=#{@hwnd}")
    return if @hwnd == 0
    safe { leave_engine_fullscreen }
    safe { load_settings }
    if engine_fullscreen?
      # Окно не в фокусе (или Alt+Enter занят другой копией игры) — применим
      # настройки позже, когда окно игры станет активным
      @deferred = true
      log('engine fullscreen is still active, apply deferred')
    else
      safe { apply }
      safe { save_settings }
    end
    # Регистрируем Alt+Enter как горячую клавишу — тогда движок не получает это
    # сочетание и не включает свой режим 640x480. Само нажатие ловим опросом
    # клавиатуры в update (WM_HOTKEY движок забирает из очереди сам).
    safe { create_bg_window }
    @hotkey_hwnd = (@bg && @bg != 0) ? @bg : @hwnd
    @hotkey = API::RegisterHotKey.call(@hotkey_hwnd, HOTKEY_ID, 0x4001, 0x0D) != 0 # MOD_ALT|MOD_NOREPEAT
    log("hotkey registered=#{@hotkey} on #{@hotkey_hwnd}")
    @keys = {}
    @ready = true
  end

  def self.shutdown
    @exiting = true
    safe do
      API::UnregisterHotKey.call(@hotkey_hwnd, HOTKEY_ID) if @hotkey
      @hotkey = false
      restore_display_mode
    end
  end

  # Нажатие с прошлого кадра (в т.ч. очень короткое — младший бит GetAsyncKeyState)
  def self.pressed_once?(vk)
    st = API::GetAsyncKeyState.call(vk)
    down = st & 0x8000 != 0
    was = @keys[vk]
    @keys[vk] = down
    (down && !was) || (!down && st & 1 != 0)
  end

  def self.alt_held?
    API::GetAsyncKeyState.call(0x12) & 0x8000 != 0
  end

  def self.update
    return unless @ready
    if @deferred
      @retry = (@retry || 0) + 1
      if @retry % 60 == 0 && foreground?
        safe { leave_engine_fullscreen }
        unless engine_fullscreen?
          @deferred = false
          safe { apply }
          safe { save_settings }
        end
      end
      return
    end
    keep_bg_below
    return if @busy || !foreground?
    alt_enter = (pressed_once?(0x0D) && alt_held?) || @hotkey_hit
    @hotkey_hit = false
    if alt_enter
      toggle_fullscreen
    elsif (pressed_once?(MENU_KEY) | Input.trigger?(:F5)) && !@menu_open
      open_menu
    end
  end

  def self.toggle_fullscreen
    if @mode == MODE_WINDOWED
      apply(@last_fullscreen_mode || MODE_BORDERLESS)
    else
      apply(MODE_WINDOWED)
    end
    save_settings
  end

  #--------------------------------------------------------------------------
  # Меню настроек (модальное, работает в любой сцене)
  #--------------------------------------------------------------------------
  def self.open_menu
    return if @menu_open || !@ready
    @menu_open = true
    @busy = true
    dim = Sprite.new
    dim.z = 99998
    dim.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    dim.bitmap.fill_rect(dim.bitmap.rect, Color.new(0, 0, 0, 160))
    win = Window_DisplayMod.new
    pressed_once?(0x1B) # сбросить накопленное нажатие Esc
    Sound.play_ok rescue nil
    loop do
      @orig_update.call
      Input.update
      keep_bg_below
      win.update
      break if win.finished?
      win.close_request if pressed_once?(MENU_KEY) | Input.trigger?(:F5)
    end
    win.dispose
    dim.bitmap.dispose
    dim.dispose
    Input.update
    @keys[MENU_KEY] = key_down?(MENU_KEY)
    @keys[0x0D] = key_down?(0x0D)
  ensure
    @menu_open = false
    @busy = false
  end
end

#==============================================================================
# ■ Window_DisplayMod — окно настроек
#==============================================================================
class Window_DisplayMod < Window_Base
  ROWS = [:mode, :res, :scale, :apply, :close]
  WIDTH = 520

  def initialize
    @index = 0
    @finished = false
    @message = nil
    load_values
    super((Graphics.width - WIDTH) / 2, 0, [WIDTH, Graphics.width].min, 248)
    self.y = (Graphics.height - height) / 2
    self.z = 99999
    self.back_opacity = 255 if respond_to?(:back_opacity=)
    refresh
  end

  def finished?; @finished; end
  def close_request; @finished = true; end

  def load_values
    @mode = DisplayMod.mode
    @win_list = DisplayMod.window_resolutions
    @fs_list = DisplayMod.fullscreen_resolutions
    @win_res = DisplayMod.win_res
    @fs_res = DisplayMod.fs_res
    @scale = DisplayMod.scale
    @win_list |= [@win_res]
    @fs_list |= [@fs_res]
    @win_list.sort!
    @fs_list.sort!
  end

  def area
    DisplayMod.target_area(@mode, @win_res, @fs_res)
  end

  def scale_list
    a = area
    DisplayMod.scale_options(a[0], a[1])
  end

  def normalize_scale
    list = scale_list
    return if list.include?(@scale)
    @scale = @scale =~ /^x/ ? list.last : 'fit'
  end

  def res_enabled?
    @mode != DisplayMod::MODE_BORDERLESS
  end

  def scale_name(s)
    case s
    when 'stretch' then DisplayMod.t(:stretch)
    when 'fit'     then DisplayMod.t(:fit)
    else
      n = s[1..-1].to_i
      "#{s} (#{DisplayMod.base_w * n}x#{DisplayMod.base_h * n})"
    end
  end

  def value_text(row)
    case row
    when :mode then DisplayMod.t(:modes)[@mode]
    when :res
      a = area
      txt = "#{a[0]}x#{a[1]}"
      res_enabled? ? txt : "#{txt} (#{DisplayMod.t(:desktop)})"
    when :scale then scale_name(@scale)
    end
  end

  def changed?
    @mode != DisplayMod.mode || @scale != DisplayMod.scale ||
      @win_res != DisplayMod.win_res || @fs_res != DisplayMod.fs_res
  end

  def row_y(i)
    line_height * (i + 1) + (i >= 3 ? line_height / 2 : 0)
  end

  def refresh
    contents.clear
    contents.font.size = 24
    change_color(system_color)
    draw_text(0, 0, contents_width, line_height, DisplayMod.t(:header), 1)
    contents.font.size = Font.default_size
    ROWS.each_with_index do |row, i|
      y = row_y(i)
      enabled = row != :res || res_enabled?
      if [:apply, :close].include?(row)
        change_color(normal_color, row != :apply || changed?)
        draw_text(0, y, contents_width, line_height, DisplayMod.t(row), 1)
      else
        change_color(system_color, enabled)
        draw_text(4, y, 200, line_height, DisplayMod.t(row))
        change_color(normal_color, enabled)
        vx = 210
        vw = contents_width - vx - 4
        draw_text(vx, y, 24, line_height, '◀') if enabled
        draw_text(vx + 24, y, vw - 48, line_height, value_text(row), 1)
        draw_text(vx + vw - 24, y, 24, line_height, '▶', 2) if enabled
      end
    end
    # Подсказка
    contents.font.size = 18
    y = row_y(5) + 4
    hint = DisplayMod.t(:"hint_#{ROWS[@index]}")
    lines = wrap_text(@message || hint, contents_width - 8)
    change_color(@message ? crisis_color : normal_color)
    lines.each_with_index do |l, i|
      draw_text(4, y + i * 20, contents_width - 8, 20, l)
    end
    contents.font.size = Font.default_size
    change_color(normal_color)
    update_cursor_rect
  end

  def wrap_text(text, width)
    lines = []
    cur = ''
    text.split(' ').each do |word|
      test = cur.empty? ? word : "#{cur} #{word}"
      if contents.text_size(test).width > width && !cur.empty?
        lines << cur
        cur = word
      else
        cur = test
      end
    end
    lines << cur unless cur.empty?
    lines
  end

  def update_cursor_rect
    cursor_rect.set(0, row_y(@index), contents_width, line_height)
  end

  def update
    super
    return if @finished
    if Input.repeat?(:DOWN)
      @index = (@index + 1) % ROWS.size
      Sound.play_cursor
      @message = nil
      refresh
    elsif Input.repeat?(:UP)
      @index = (@index - 1) % ROWS.size
      Sound.play_cursor
      @message = nil
      refresh
    elsif Input.repeat?(:RIGHT)
      change_value(1)
    elsif Input.repeat?(:LEFT)
      change_value(-1)
    elsif Input.trigger?(:C)
      process_ok
    elsif Input.trigger?(:B) || DisplayMod.pressed_once?(0x1B)
      Sound.play_cancel
      @finished = true
    end
  end

  def cycle(list, cur, dir)
    i = list.index(cur) || 0
    list[(i + dir) % list.size]
  end

  def change_value(dir)
    row = ROWS[@index]
    case row
    when :mode
      @mode = (@mode + dir) % 3
    when :res
      return Sound.play_buzzer unless res_enabled?
      if @mode == DisplayMod::MODE_WINDOWED
        @win_res = cycle(@win_list, @win_res, dir)
      else
        @fs_res = cycle(@fs_list, @fs_res, dir)
      end
    when :scale
      @scale = cycle(scale_list, @scale, dir)
    else
      return
    end
    normalize_scale
    Sound.play_cursor
    @message = nil
    refresh
  end

  def process_ok
    case ROWS[@index]
    when :mode, :res, :scale
      change_value(1)
    when :apply
      return Sound.play_buzzer unless changed?
      Sound.play_ok
      normalize_scale
      ok = DisplayMod.apply(@mode, @win_res, @fs_res, @scale)
      DisplayMod.save_settings
      load_values
      @message = DisplayMod.t(ok ? :applied : :failed)
      refresh
    when :close
      Sound.play_cancel
      @finished = true
    end
  end
end

#==============================================================================
# ■ Graphics — покадровый хук
#==============================================================================
class << Graphics
  unless method_defined?(:display_mod_update)
    alias display_mod_update update
    def update
      display_mod_update
      DisplayMod.safe { DisplayMod.update }
    end
  end
end

#==============================================================================
# ■ Титульный экран — пункт «Настройки экрана»
#==============================================================================
class Window_TitleCommand < Window_Command
  unless method_defined?(:display_mod_make_command_list)
  alias display_mod_make_command_list make_command_list
  def make_command_list
    display_mod_make_command_list
    idx = @list.index { |c| c[:symbol] == :shutdown } || @list.size
    @list.insert(idx, { :name => DisplayMod.t(:title_cmd), :symbol => :display_mod,
                        :enabled => true, :ext => nil })
  end

  alias display_mod_window_width window_width
  def window_width
    w = display_mod_window_width
    DisplayMod.language == :ru ? [w, 220].max : w
  end

  alias display_mod_update_placement update_placement
  def update_placement
    display_mod_update_placement
    self.y = [y, Graphics.height - height - 4].min
  end
  end
end

class Scene_Title < Scene_Base
  unless method_defined?(:display_mod_create_command_window)
  alias display_mod_create_command_window create_command_window
  def create_command_window
    display_mod_create_command_window
    @command_window.set_handler(:display_mod, method(:command_display_mod))
  end

  def command_display_mod
    DisplayMod.open_menu
    @command_window.activate
  end
  end
end

#==============================================================================
# ■ Выход из игры — вернуть разрешение монитора и снять перехват Alt+Enter
#   (Windows и сам возвращает разрешение при закрытии процесса)
#==============================================================================
module SceneManager
  class << self
    unless method_defined?(:display_mod_exit)
      alias display_mod_exit exit
      def exit
        DisplayMod.shutdown
        display_mod_exit
      end
    end
  end
end
at_exit { DisplayMod.shutdown } unless DisplayMod.instance_variable_get(:@ready)

DisplayMod.safe { DisplayMod.setup(Graphics.method(:display_mod_update)) }
