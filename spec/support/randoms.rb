def random_string(tag = "random")
  sprintf("%s-%x", tag, rand(10 ** 6))
end