/// A simple test function with some intentional linting issues
pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

/// Function with intentional clippy warnings
pub fn example_with_warnings() -> i32 {
    let mut x = 0;
    x = 42; // This could be simplified
    return x; // Unnecessary return
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
    
    #[test]
    fn test_warnings() {
        let result = example_with_warnings();
        assert_eq!(result, 42);
    }
}