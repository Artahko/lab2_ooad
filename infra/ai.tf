resource "aws_iam_role" "ai_parser_role" {
  name = "${var.project_name}-ai-parser-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ai_parser_basic" {
  role       = aws_iam_role.ai_parser_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "bedrock_mantle" {
  name = "${var.project_name}-bedrock-mantle-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "bedrock-mantle:CreateInference"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ai_parser_bedrock" {
  role       = aws_iam_role.ai_parser_role.name
  policy_arn = aws_iam_policy.bedrock_mantle.arn
}
