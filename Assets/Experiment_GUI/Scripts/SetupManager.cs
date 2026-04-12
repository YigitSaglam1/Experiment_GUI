using System;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
[Serializable]
public struct FieldsNWarning
{
    public TMP_InputField field;
    public TMP_Text warning;
}
public class SetupManager : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private List<FieldsNWarning> inputFields = new List<FieldsNWarning>();
    private void Start()
    {
        foreach (var input in inputFields)
        {
            input.warning.text = string.Empty;
        }
    }
    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space)) StartExperimentButton();
    }
    public void StartExperimentButton()
    {
        List<float> inputValues = new List<float>();
        foreach (var input in inputFields)
        {
            if (!InputValidation.TryGetFloat(input.field.text, out float value))
            {
                input.warning.text = $"Invalid input in field: '{input.field.text}' is not a valid number.";
            }
            else
            {
                input.warning.text = string.Empty; 
                inputValues.Add(value);
            }
        }
        if (inputValues.Count != inputFields.Count) return;
        else ExperimentManager.Instance.SetExperimentData(inputValues);
    }
}
