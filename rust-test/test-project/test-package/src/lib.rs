/// A simple calculator library for testing
pub fn add(left: u64, right: u64) -> u64 {
    left + right
}

pub fn subtract(left: u64, right: u64) -> u64 {
    left - right
}

pub fn multiply(left: u64, right: u64) -> u64 {
    left * right
}

pub fn divide(left: u64, right: u64) -> Option<u64> {
    if right == 0 {
        None
    } else {
        Some(left / right)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
        assert_eq!(add(0, 5), 5);
        assert_eq!(add(10, 20), 30);
    }
    
    #[test]
    fn test_subtract() {
        assert_eq!(subtract(10, 5), 5);
        assert_eq!(subtract(100, 50), 50);
        assert_eq!(subtract(5, 5), 0);
    }
    
    #[test]
    fn test_multiply() {
        assert_eq!(multiply(3, 4), 12);
        assert_eq!(multiply(0, 10), 0);
        assert_eq!(multiply(7, 1), 7);
    }
    
    #[test]
    fn test_divide() {
        assert_eq!(divide(10, 2), Some(5));
        assert_eq!(divide(0, 5), Some(0));
        assert_eq!(divide(10, 0), None);
        assert_eq!(divide(15, 3), Some(5));
    }
}