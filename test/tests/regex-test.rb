@regex = /(?<braces>\{(?:[^{}]|\g<braces>)*\})/x

def find_nested_braces(string)
  string.scan(@regex).flatten
end

# Example usage
input = "This is {a {nested} example} of {nested {} structure} }"
# p find_nested_braces(input)
puts(input.match(@regex).inspect)
