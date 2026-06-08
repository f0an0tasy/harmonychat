/**
 * 登录界面输入区组件。
 *
 * @author wangyifan & qinweiming
 */
@Component
export struct LoginInputView {
  @Link loginName: string;
  @Link loginPassword: string;
  @Link passwordFocused: boolean;

  build() {
    Column() {
      this.TextLine({ bottom: 5 })
      Row() {
        Text('登录账号')
          .fontColor('#0e1a26')
          .fontWeight(500)
        TextInput({ text: $$this.loginName, placeholder: '请输入用户名' })
          .inputStyle()
          .margin({ right: 5 })
      }
      .height(52)

      this.TextLine({})

      Row() {
        Text('登录密码')
          .fontColor('#0e1a26')
          .fontWeight(500)

        TextInput({ text: $$this.loginPassword, placeholder: '请输入密码' })
          .inputStyle()
          .type(InputType.Password)
          .margin({ right: 5 })
          .passwordIcon({ onIconSrc: $r('app.media.login_showpass_on'), offIconSrc: $r('app.media.login_showpass_off'), })
          .onFocus(() => {
            this.passwordFocused = true;
          })
          .onBlur(() => {
            this.passwordFocused = false;
          })
      }
      .height(52)
      .margin({ top: 5, })

      this.TextLine({})
    }
    .width('100%')
    .margin({ top: 40 })
  }

  @Builder
  TextLine(margin: Margin) {
    Line()
      .height(0.5)
      .width('100%')
      .backgroundColor('#d0d2d6')
      .padding({ left: 12, right: 12 })
      .margin(margin)
  }
}

@Extend(TextInput)
function inputStyle() {
  .width('100%')
  .height('100%')
  .layoutWeight(1)
  .maxLength(16)
  .fontColor('#353535')
  .placeholderColor('#a1a7af')
  .backgroundColor(Color.Transparent)
}