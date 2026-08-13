#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

/// Saluda a un nombre. Expuesto a Dart y llamable desde las páginas Lua.
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// Suma dos enteros. Ejemplo de lógica de negocio en Rust.
#[flutter_rust_bridge::frb(sync)]
pub fn sum(a: i64, b: i64) -> i64 {
    a + b
}

/// Fibonacci iterativo (rápido). Ejemplo de cálculo pesado en Rust.
#[flutter_rust_bridge::frb(sync)]
pub fn fibonacci(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let (mut a, mut b) = (0u64, 1u64);
            for _ in 2..=n {
                let next = a + b;
                a = b;
                b = next;
            }
            b
        }
    }
}