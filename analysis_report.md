# Phân Tích Project Itsycal

Project **Itsycal** là một ứng dụng lịch nhỏ gọn nằm trên thanh menu (Menu Bar) của macOS. Ứng dụng này cho phép người dùng xem nhanh lịch tháng, danh sách sự kiện sắp tới và tạo sự kiện mới mà không cần mở ứng dụng Calendar đầy đủ.

## 1. Ngôn Ngữ & Công Nghệ
- **Ngôn ngữ chính:** Objective-C (`.m`, `.h`).
- **Nền tảng:** macOS (Cocoa / AppKit).
- **Công cụ build:** Xcode (`.xcodeproj`).
- **Libraries/External Frameworks:**
    - **AppKit:** Giao diện người dùng macOS.
    - **EventKit:** Tương tác với dữ liệu lịch của hệ thống (Calendar.app).
    - **Sparkle:** Hỗ trợ tính năng tự động cập nhật ứng dụng.
    - **MASShortcut:** Quản lý phím tắt toàn cục (Global Keyboard Shortcuts).

## 2. Business Logic

Luồng hoạt động chính của ứng dụng xoay quanh `ViewController` (quản lý giao diện chính) và `EventCenter` (quản lý dữ liệu lịch).

### Core Flow:
1.  **Khởi động (`AppDelegate`):**
    -   Thiết lập các cấu hình mặc định (`NSUserDefaults`).
    -   Khởi tạo `EventCenter` để xin quyền truy cập Calendar.
    -   Khởi tạo `NSStatusItem` để hiển thị icon/đồng hồ trên Menu Bar.

2.  **Hiển thị & Tương tác (`ViewController`, `MoCalendar`):**
    -   Khi người dùng click vào icon trên menu bar, cửa sổ popover hiện ra.
    -   `MoCalendar`: Vẽ lưới lịch tháng, xử lý highlight ngày hiện tại, ngày cuối tuần, và ngày được chọn.
    -   `AgendaViewController`: Hiển thị danh sách sự kiện trong ngày (hoặc các ngày tới) dựa trên dữ liệu từ `EventCenter`.

3.  **Xử lý dữ liệu Lịch (`EventCenter`):**
    -   Lắng nghe thay đổi từ `EKEventStore` (cơ sở dữ liệu lịch của macOS).
    -   Fetch sự kiện (`fetchEvents`) dựa trên khoảng thời gian đang hiển thị.
    -   Filter sự kiện dựa trên các lịch mà người dùng đã chọn hiển thị (`kSelectedCalendars`).
    -   **Tính năng đặc biệt:** Phân tích `notes` hoặc `location` của sự kiện để tìm link họp online (Zoom, Teams, Google Meet...) và tạo nút tham gia nhanh (`checkForZoomURL`).

## 3. Phân Loại Chức Năng

### Chức Năng Chính (Core Features)
Đây là những chức năng cốt lõi tạo nên giá trị chính của ứng dụng:

1.  **Menu Bar Item:**
    -   Hiển thị Icon hoặc Ngày/Tháng hiện tại trên thanh menu.
    -   Tùy chỉnh định dạng đồng hồ (Clock format) thay thế cho đồng hồ mặc định của macOS.
2.  **Lịch Tháng (Monthly Calendar View):**
    -   Xem lịch theo tháng dạng lưới (Grid).
    -   Điều hướng giữa các tháng.
    -   Highlight ngày hôm nay và các ngày có sự kiện (Event dots).
3.  **Danh Sách Sự Kiện (Agenda View):**
    -   Hiển thị danh sách sự kiện của ngày được chọn và các ngày tiếp theo.
    -   Hiển thị chi tiết thời gian, địa điểm, tiêu đề sự kiện.
4.  **Tương Tác Sự Kiện:**
    -   Mở sự kiện trực tiếp trong ứng dụng Calendar mặc định (Calendar.app, Fantastical, BusyCal).
    -   Tham gia họp trực tuyến nhanh (Detect Zoom/Teams/Meet links).

### Chức Năng Phụ (Secondary/Support Features)
Các tính năng bổ trợ, giúp nâng cao trải nghiệm người dùng:

1.  **Tạo Sự Kiện Mới:**
    -   Cho phép tạo nhanh sự kiện đơn giản (Quick Entry) trực tiếp từ Itsycal.
2.  **Tùy Biến Giao Diện (Theming & Appearance):**
    -   Chế độ Sáng/Tối (Light/Dark mode) hoặc theo hệ thống.
    -   Tùy chỉnh ngày đầu tuần (First day of week).
    -   Highlight ngày cuối tuần hoặc các ngày đặc biệt.
    -   Tùy chỉnh kích thước cửa sổ và font chữ.
3.  **Phím Tắt Toàn Cục (Global Shortcut):**
    -   Cài đặt phím tắt để mở nhanh cửa sổ Itsycal từ bất kỳ đâu.
4.  **Ghim Cửa Sổ (Pin Window):**
    -   Giữ cửa sổ luôn mở (không tự đóng khi focus ra ngoài) để tiện theo dõi.
5.  **Tự Động Cập Nhật:**
    -   Kiểm tra và cài đặt bản cập nhật mới qua Sparkle.
6.  **Hỗ Trợ Đa Ngôn Ngữ (Localization):**
    -   Hỗ trợ nhiều ngôn ngữ (English, Italian, Spanish, French, v.v...).

---
*Phân tích dựa trên source code tại `/Users/tainv3/Desktop/Projects/Itsycal`.*
