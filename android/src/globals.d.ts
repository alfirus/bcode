/// <reference types="acode-plugin-types" />
declare module "*.css" {
  const content: string;
  export default content;
}

declare var acode: Acode.Acode;
declare var editorManager: {
  editor?: {
    commands: {
      addCommand(cmd: { name: string; description: string; exec: () => boolean }): void;
      removeCommand(name: string): void;
    };
  };
};
