const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../../models/auth/user.model");
const Otp = require("../../models/auth/otp.model");
const transporter = require("../../config/mailer");
const generateOtp = require("../../utils/auth/generateOtp");

const sendOtpEmail = async (email, otp) => {
  await transporter.sendMail({
    from: process.env.MAIL_FROM,
    to: email,
    subject: "Verify your email - OTP",
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Email Verification</h2>
        <p>Your OTP for email verification is:</p>
        <h1 style="letter-spacing: 4px;">${otp}</h1>
        <p>This OTP will expire in 10 minutes.</p>
      </div>
    `,
  });
};

const registerUser = async ({ name, number, email, password }) => {
  const existingUser = await User.findOne({ email });

  if (existingUser && existingUser.isVerified) {
    throw new Error("User already exists and is verified");
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  let user;

  if (existingUser) {
    existingUser.name = name;
    existingUser.number = number;
    existingUser.password = hashedPassword;
    existingUser.isVerified = false;
    user = await existingUser.save();
  } else {
    user = await User.create({
      name,
      number,
      email,
      password: hashedPassword,
      isVerified: false,
    });
  }

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  await Otp.deleteMany({ email });

  await Otp.create({
    email,
    otp,
    expiresAt,
  });

  await sendOtpEmail(email, otp);

  return {
    message: "Registration successful. OTP sent to email.",
    email,
  };
};

const verifyUserOtp = async ({ email, otp }) => {
  const otpDoc = await Otp.findOne({ email, otp });

  if (!otpDoc) {
    throw new Error("Invalid OTP");
  }

  if (new Date() > otpDoc.expiresAt) {
    await Otp.deleteMany({ email });
    throw new Error("OTP expired");
  }

  const user = await User.findOne({ email });

  if (!user) {
    throw new Error("User not found");
  }

  user.isVerified = true;
  await user.save();

  await Otp.deleteMany({ email });

  const token = jwt.sign(
    { userId: user._id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

  return {
    message: "Email verified successfully",
    token,
    user: {
      id: user._id,
      name: user.name,
      number: user.number,
      email: user.email,
    },
  };
};

const resendOtp = async ({ email }) => {
  const user = await User.findOne({ email });

  if (!user) {
    throw new Error("User not found");
  }

  if (user.isVerified) {
    throw new Error("User already verified");
  }

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  await Otp.deleteMany({ email });

  await Otp.create({
    email,
    otp,
    expiresAt,
  });

  await sendOtpEmail(email, otp);

  return {
    message: "OTP resent successfully",
  };
};

const loginUser = async ({ email, password }) => {
  const user = await User.findOne({ email });

  if (!user) {
    throw new Error("Invalid email or password");
  }

  if (!user.isVerified) {
    throw new Error("Please verify your email first");
  }

  const isMatch = await bcrypt.compare(password, user.password);

  if (!isMatch) {
    throw new Error("Invalid email or password");
  }

  const token = jwt.sign(
    {
      userId: user._id,
      email: user.email,
    },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

  return {
    message: "Login successful",
    token,
    user: {
      id: user._id,
      name: user.name,
      number: user.number,
      email: user.email,
    },
  };
};

module.exports = {
  registerUser,
  verifyUserOtp,
  resendOtp,
  loginUser,
};